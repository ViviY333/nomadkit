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
    let countryID: String
    let days: Int
    let checkedInAt: Date
}

struct TravelStats: Equatable {
    let cityCount: Int
    let countryCount: Int
    let totalDays: Int
}
