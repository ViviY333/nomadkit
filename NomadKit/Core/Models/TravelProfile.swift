import Foundation

struct BadgeCatalog: Codable {
    let badges: [BadgeDefinition]
}

struct BadgeDefinition: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedCopy
    let detail: LocalizedCopy
    let symbol: String
    let tone: SystemTone
    let rule: BadgeRule
}

struct BadgeRule: Codable, Hashable {
    let metric: BadgeMetric
    let threshold: Int
}

enum BadgeMetric: String, Codable, Hashable {
    case cityCount
    case countryCount
    case totalDays
    case checklistCount
}

struct TravelVisit: Codable, Identifiable, Hashable {
    let id: UUID
    let cityID: String
    let cityName: LocalizedCopy
    /// ISO 3166-1 alpha-2 code. Kept under the legacy key name for migration compatibility.
    let countryID: String
    let countryName: LocalizedCopy
    let latitude: Double?
    let longitude: Double?
    let days: Int
    let checkedInAt: Date
    let source: VisitSource

    var coordinate: (latitude: Double, longitude: Double)? {
        guard let latitude, let longitude else { return nil }
        return (latitude, longitude)
    }

    init(
        id: UUID = UUID(),
        cityID: String,
        cityName: LocalizedCopy,
        countryID: String,
        countryName: LocalizedCopy,
        latitude: Double? = nil,
        longitude: Double? = nil,
        days: Int,
        checkedInAt: Date,
        source: VisitSource = .cityCheckIn
    ) {
        self.id = id
        self.cityID = cityID
        self.cityName = cityName
        self.countryID = CountryCatalog.code(for: countryID)
        self.countryName = countryName
        self.latitude = latitude
        self.longitude = longitude
        self.days = days
        self.checkedInAt = checkedInAt
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id, cityID, cityName, countryID, countryName, latitude, longitude, days, checkedInAt, source
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacyCountry = try values.decodeIfPresent(String.self, forKey: .countryID) ?? ""
        let countryCode = CountryCatalog.code(for: legacyCountry)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cityID = try values.decodeIfPresent(String.self, forKey: .cityID) ?? "unknown"
        cityName = try values.decodeIfPresent(LocalizedCopy.self, forKey: .cityName)
            ?? LocalizedCopy(zhHans: "未知地点", en: "Unknown place")
        countryID = countryCode
        countryName = try values.decodeIfPresent(LocalizedCopy.self, forKey: .countryName)
            ?? CountryCatalog.name(for: countryCode)
        latitude = try values.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try values.decodeIfPresent(Double.self, forKey: .longitude)
        days = try values.decodeIfPresent(Int.self, forKey: .days) ?? 1
        checkedInAt = try values.decodeIfPresent(Date.self, forKey: .checkedInAt) ?? .now
        source = try values.decodeIfPresent(VisitSource.self, forKey: .source) ?? .migrated
    }
}

enum VisitSource: String, Codable, Hashable {
    case cityCheckIn
    case manual
    case photo
    case migrated
}

enum CountryCatalog {
    static let stampAssets: [String: String] = [
        "AU": "StampAU", "DE": "StampDE", "FR": "StampFR", "CA": "StampCA", "GB": "StampGB",
        "JP": "StampJP", "CN": "StampCN", "US": "StampUS", "IT": "StampIT"
    ]

    static func code(for value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.count == 2 { return normalized }
        return legacyCodes[normalized] ?? normalized
    }

    static func name(for code: String) -> LocalizedCopy {
        names[code.uppercased()] ?? LocalizedCopy(zhHans: code, en: code)
    }

    static func stampAsset(for code: String) -> String? {
        stampAssets[code.uppercased()]
    }

    private static let legacyCodes: [String: String] = [
        "THAILAND": "TH", "TAIWAN": "TW", "CHINA": "CN", "JAPAN": "JP", "UNITED STATES": "US",
        "UNITED STATES OF AMERICA": "US", "ITALY": "IT", "FRANCE": "FR", "GERMANY": "DE",
        "CANADA": "CA", "UNITED KINGDOM": "GB", "AUSTRALIA": "AU", "PORTUGAL": "PT", "SPAIN": "ES"
    ]

    private static let names: [String: LocalizedCopy] = [
        "TH": LocalizedCopy(zhHans: "泰国", en: "Thailand"), "TW": LocalizedCopy(zhHans: "中国台湾", en: "Taiwan"),
        "CN": LocalizedCopy(zhHans: "中国", en: "China"), "JP": LocalizedCopy(zhHans: "日本", en: "Japan"),
        "US": LocalizedCopy(zhHans: "美国", en: "United States"), "IT": LocalizedCopy(zhHans: "意大利", en: "Italy"),
        "FR": LocalizedCopy(zhHans: "法国", en: "France"), "DE": LocalizedCopy(zhHans: "德国", en: "Germany"),
        "CA": LocalizedCopy(zhHans: "加拿大", en: "Canada"), "GB": LocalizedCopy(zhHans: "英国", en: "United Kingdom"),
        "AU": LocalizedCopy(zhHans: "澳大利亚", en: "Australia"), "PT": LocalizedCopy(zhHans: "葡萄牙", en: "Portugal"),
        "ES": LocalizedCopy(zhHans: "西班牙", en: "Spain")
    ]
}

struct TravelStats: Equatable {
    let cityCount: Int
    let countryCount: Int
    let totalDays: Int
}
