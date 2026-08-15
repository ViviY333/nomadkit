import Foundation

struct SafetyCatalog: Codable {
    let categories: [SafetyCategory]
}

struct SafetyCategory: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedCopy
    let summary: LocalizedCopy
    let symbol: String
    let tone: SystemTone
    let updatedAt: String
    let items: [SafetyItem]
    let channel: LocalizedCopy
    let pitfall: LocalizedCopy
}

struct SafetyItem: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedCopy
    let detail: LocalizedCopy
}
