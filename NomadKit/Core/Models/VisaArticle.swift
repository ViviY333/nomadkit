import Foundation

struct VisaArticleCatalog: Codable {
    let articles: [VisaArticle]
}

struct VisaArticle: Codable, Identifiable, Hashable {
    let id: String
    let countryCode: String
    let country: LocalizedCopy
    let title: LocalizedCopy
    let summary: LocalizedCopy
    let symbol: String
    let tone: SystemTone
    let status: LocalizedCopy
    let updatedAt: String
    let readTimeMinutes: Int
    let keyFacts: [VisaKeyFact]
    let notice: VisaArticleNotice
    let sections: [VisaArticleSection]
    let sources: [VisaSource]
    let disclaimer: LocalizedCopy
}

struct VisaKeyFact: Codable, Identifiable, Hashable {
    let id: String
    let label: LocalizedCopy
    let value: LocalizedCopy
    let detail: LocalizedCopy
}

struct VisaArticleNotice: Codable, Hashable {
    let title: LocalizedCopy
    let body: LocalizedCopy
    let tone: SystemTone
}

struct VisaArticleSection: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedCopy
    let paragraphs: [LocalizedCopy]
    let highlights: [VisaHighlight]
    let bullets: [LocalizedCopy]
}

struct VisaHighlight: Codable, Identifiable, Hashable {
    let id: String
    let label: LocalizedCopy
    let detail: LocalizedCopy
    let tone: SystemTone
}

struct VisaSource: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedCopy
    let publisher: LocalizedCopy
    let url: URL
}
