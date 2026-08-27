import Foundation

enum VisaRequirementKind: String, Codable, Sendable {
    case visaFree
    case eVisa
    case eTA
    case visaOnArrival
    case visaRequired
    case check

    var isVisaFree: Bool { self == .visaFree }
}

struct VisaAccessItem: Identifiable, Codable, Sendable {
    let countryCode: String
    let kind: VisaRequirementKind
    let sourceURL: String?

    var id: String { countryCode }
}

struct VisaPassportAccess: Codable, Sendable {
    let passportCode: String
    let items: [VisaAccessItem]
    let sourceName: String
    let sourceURL: String
    let fetchedAt: Date
}

enum VisaAccessError: LocalizedError {
    case invalidResponse
    case requestFailed(Int)
    case noCoverage

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The visa service returned an invalid response."
        case .requestFailed(let status): "The visa service returned HTTP \(status)."
        case .noCoverage: "No visa data is available for this passport."
        }
    }
}

actor VisaAccessService {
    static let shared = VisaAccessService()

    private let cacheLifetime: TimeInterval = 7 * 24 * 60 * 60
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func access(for passportCode: String) async throws -> VisaPassportAccess {
        let passport = passportCode.uppercased()
        if let cached = cachedAccess(for: passport), Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached
        }

        do {
            let access: VisaPassportAccess
            if let key = travelBuddyAPIKey {
                do {
                    access = try await fetchTravelBuddyMap(passport: passport, apiKey: key)
                } catch {
                    access = try await fetchPassportIndexMap(passport: passport)
                }
            } else {
                do {
                    access = try await fetchPassportIndexMap(passport: passport)
                } catch {
                    access = try await fetchToshikoMap(passport: passport)
                }
            }
            save(access)
            return access
        } catch {
            if let stale = cachedAccess(for: passport) { return stale }
            throw error
        }
    }

    private var travelBuddyAPIKey: String? {
        let key = ProcessInfo.processInfo.environment["TRAVEL_BUDDY_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return key?.isEmpty == false ? key : nil
    }

    private func fetchTravelBuddyMap(passport: String, apiKey: String) async throws -> VisaPassportAccess {
        guard let url = URL(string: "https://visa-requirement.p.rapidapi.com/v2/visa/map") else {
            throw VisaAccessError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("visa-requirement.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["passport": passport])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw VisaAccessError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let root = try JSONSerialization.jsonObject(with: data)
        guard let map = findColorMap(in: root) else { throw VisaAccessError.invalidResponse }

        let mappings: [(String, VisaRequirementKind)] = [
            ("green", .visaFree),
            ("blue", .visaOnArrival),
            ("yellow", .eTA),
            ("red", .visaRequired)
        ]
        let items = mappings.flatMap { color, kind in
            countryCodes(from: map[color]).map { VisaAccessItem(countryCode: $0, kind: kind, sourceURL: nil) }
        }
        guard !items.isEmpty else { throw VisaAccessError.noCoverage }
        return VisaPassportAccess(passportCode: passport, items: items, sourceName: "Travel Buddy", sourceURL: "https://travel-buddy.ai/api/", fetchedAt: .now)
    }

    private func fetchPassportIndexMap(passport: String) async throws -> VisaPassportAccess {
        guard let url = URL(string: "https://raw.githubusercontent.com/imorte/passport-index-data/main/passport-index.json") else {
            throw VisaAccessError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw VisaAccessError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let payload = try decoder.decode([String: [String: PassportIndexDestination]].self, from: data)
        guard let destinations = payload[passport] else { throw VisaAccessError.noCoverage }

        let items = destinations.compactMap { code, destination -> VisaAccessItem? in
            let countryCode = code.uppercased()
            guard countryCode.count == 2, countryCode != passport else { return nil }
            return VisaAccessItem(
                countryCode: countryCode,
                kind: VisaRequirementKind(passportIndexStatus: destination.status),
                sourceURL: nil
            )
        }
        guard !items.isEmpty else { throw VisaAccessError.noCoverage }
        return VisaPassportAccess(
            passportCode: passport,
            items: items,
            sourceName: "Passport Index Data",
            sourceURL: "https://github.com/imorte/passport-index-data",
            fetchedAt: .now
        )
    }

    private func fetchToshikoMap(passport: String) async throws -> VisaPassportAccess {
        guard let url = URL(string: "https://toshikovisa.com/api/v1/passports/\(passport)") else {
            throw VisaAccessError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw VisaAccessError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let payload = try decoder.decode(ToshikoPassportResponse.self, from: data)
        let items = payload.destinations.map { destination in
            VisaAccessItem(
                countryCode: destination.code.uppercased(),
                kind: VisaRequirementKind(toshikoOutcome: destination.outcome),
                sourceURL: destination.url
            )
        }
        guard !items.isEmpty else { throw VisaAccessError.noCoverage }
        return VisaPassportAccess(
            passportCode: passport,
            items: items,
            sourceName: payload.attribution?.source ?? "Toshiko",
            sourceURL: payload.attribution?.url ?? "https://toshikovisa.com",
            fetchedAt: .now
        )
    }

    private func findColorMap(in value: Any) -> [String: Any]? {
        guard let object = value as? [String: Any] else { return nil }
        if object.keys.contains(where: { ["green", "blue", "yellow", "red"].contains($0.lowercased()) }) {
            return Dictionary(uniqueKeysWithValues: object.map { ($0.key.lowercased(), $0.value) })
        }
        for key in ["data", "map", "colors", "visa_map"] {
            if let nested = object[key], let result = findColorMap(in: nested) { return result }
        }
        return nil
    }

    private func countryCodes(from value: Any?) -> [String] {
        if let string = value as? String {
            return string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        }
        if let strings = value as? [String] { return strings.map { $0.uppercased() } }
        if let objects = value as? [[String: Any]] {
            return objects.compactMap { object in
                (object["countryCode"] as? String ?? object["code"] as? String)?.uppercased()
            }
        }
        return []
    }

    private func cacheKey(for passport: String) -> String { "visa.access.cache.v2.\(passport)" }

    private func cachedAccess(for passport: String) -> VisaPassportAccess? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: passport)) else { return nil }
        return try? decoder.decode(VisaPassportAccess.self, from: data)
    }

    private func save(_ access: VisaPassportAccess) {
        guard let data = try? encoder.encode(access) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: access.passportCode))
    }
}

private struct PassportIndexDestination: Decodable {
    let status: String
}

private struct ToshikoPassportResponse: Decodable {
    struct Destination: Decodable {
        let code: String
        let outcome: String
        let url: String?
    }

    struct Attribution: Decodable {
        let source: String?
        let url: String?
    }

    let destinations: [Destination]
    let attribution: Attribution?
}

extension VisaRequirementKind {
    init(toshikoOutcome: String) {
        switch toshikoOutcome.lowercased() {
        case "visa_free", "no_visa", "visa_waiver", "free_movement", "freedom_of_movement", "keta_exempt": self = .visaFree
        case "evisa", "e_visa": self = .eVisa
        case "eta", "e_ta", "esta", "nzeta", "evisitor": self = .eTA
        case "visa_on_arrival", "voa": self = .visaOnArrival
        case "visa", "visa_required": self = .visaRequired
        default: self = .check
        }
    }

    init(passportIndexStatus: String) {
        switch passportIndexStatus.lowercased() {
        case "visa free": self = .visaFree
        case "e-visa": self = .eVisa
        case "eta": self = .eTA
        case "visa on arrival": self = .visaOnArrival
        case "visa required": self = .visaRequired
        default: self = .check
        }
    }
}
