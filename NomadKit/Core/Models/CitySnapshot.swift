import Foundation

struct CityCatalog: Codable {
    let cities: [CitySnapshot]
}

struct CitySnapshot: Codable, Identifiable, Hashable {
    let id: String
    let name: LocalizedCopy
    let country: LocalizedCopy
    let arrivalDay: Int
    let updatedAt: String
    let headline: LocalizedCopy
    let summary: LocalizedCopy
    let moments: [LocalMoment]
    let survival: SurvivalOverview
    let workspaces: [Workspace]
    let reminders: [LocalReminder]
    let channels: [LocalChannel]
    let stay: StayWindow
    let disclaimer: LocalizedCopy

    var countryCode: String {
        switch id {
        case "taipei": "TW"
        case "chiang-mai", "bangkok": "TH"
        default: "TH"
        }
    }

    var arrivalStatus: String {
        let format = NSLocalizedString("today.arrival.format", comment: "City arrival status")
        return String.localizedStringWithFormat(format, name.value, arrivalDay)
    }
}

struct LocalizedCopy: Codable, Hashable {
    let zhHans: String
    let en: String

    var value: String { Locale.current.identifier.hasPrefix("zh") ? zhHans : en }

    func value(for locale: Locale) -> String {
        locale.identifier.hasPrefix("zh") ? zhHans : en
    }
}

struct LocalMoment: Codable, Identifiable, Hashable {
    let id: String
    let label: LocalizedCopy
    let value: LocalizedCopy
    let detail: LocalizedCopy
    let symbol: String
    let tone: SystemTone
}

struct SurvivalOverview: Codable, Hashable {
    let score: Int
    let title: LocalizedCopy
    let metrics: [SurvivalMetric]
}

struct SurvivalMetric: Codable, Identifiable, Hashable {
    let id: String
    let label: LocalizedCopy
    let value: Double
    let status: LocalizedCopy
}

struct Workspace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let detail: LocalizedCopy
    let distanceMeters: Int
    let symbol: String
    let manuallyVerified: Bool
    let verifiedAt: String?

    init(id: String, name: String, detail: LocalizedCopy, distanceMeters: Int, symbol: String, manuallyVerified: Bool = false, verifiedAt: String? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.distanceMeters = distanceMeters
        self.symbol = symbol
        self.manuallyVerified = manuallyVerified
        self.verifiedAt = verifiedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, detail, distanceMeters, symbol, manuallyVerified, verifiedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        detail = try values.decode(LocalizedCopy.self, forKey: .detail)
        distanceMeters = try values.decode(Int.self, forKey: .distanceMeters)
        symbol = try values.decode(String.self, forKey: .symbol)
        manuallyVerified = try values.decodeIfPresent(Bool.self, forKey: .manuallyVerified) ?? false
        verifiedAt = try values.decodeIfPresent(String.self, forKey: .verifiedAt)
    }
}

struct LocalReminder: Codable, Identifiable, Hashable {
    let id: String
    let kind: ReminderKind
    let title: LocalizedCopy
    let detail: LocalizedCopy
    let symbol: String
    let tone: SystemTone
}

enum ReminderKind: String, Codable, Hashable {
    case visa
    case weather
    case event
}

struct LocalChannel: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedCopy
    let detail: LocalizedCopy
    let symbol: String
    let tone: SystemTone
}

enum SystemTone: String, Codable, Hashable {
    case blue
    case orange
    case green
    case teal
    case indigo
    case pink
}

struct StayWindow: Codable, Hashable {
    let entryDate: String
    let allowedStayDays: Int
    let sourceUpdatedAt: String

    var countdown: TravelCountdown? {
        guard let entryDate = ISO8601DayFormatter.date(from: entryDate) else { return nil }
        return TravelCountdown(entryDate: entryDate, allowedStayDays: allowedStayDays)
    }
}

struct TravelCountdown: Hashable {
    let entryDate: Date
    let allowedStayDays: Int

    func latestDeparture(using calendar: Calendar = .autoupdatingCurrent) -> Date? {
        calendar.date(byAdding: .day, value: max(allowedStayDays - 1, 0), to: entryDate)
    }

    func remainingDays(on date: Date = .now, using calendar: Calendar = .autoupdatingCurrent) -> Int? {
        guard let latestDeparture = latestDeparture(using: calendar) else { return nil }
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: latestDeparture)
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}

enum ISO8601DayFormatter {
    static func date(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
