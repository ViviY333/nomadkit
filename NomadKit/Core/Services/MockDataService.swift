import Foundation

enum MockDataError: LocalizedError {
    case missingResource
    case emptyCatalog

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return NSLocalizedString("error.data.missing", comment: "Missing bundled mock data")
        case .emptyCatalog:
            return NSLocalizedString("error.data.empty", comment: "Empty bundled mock data")
        }
    }
}

struct MockDataService {
    func loadCities(bundle: Bundle = .main) throws -> [CitySnapshot] {
        let data: Data
        if let url = bundle.url(forResource: "cities", withExtension: "json") {
            data = try Data(contentsOf: url)
        } else if let cachedURL = Self.offlineURL(for: "cities") {
            data = try Data(contentsOf: cachedURL)
        } else {
            throw MockDataError.missingResource
        }
        return try decodeCities(from: data)
    }

    func decodeCities(from data: Data) throws -> [CitySnapshot] {
        let catalog = try JSONDecoder().decode(CityCatalog.self, from: data)
        guard !catalog.cities.isEmpty else { throw MockDataError.emptyCatalog }
        return catalog.cities
    }

    func loadSafetyCategories(bundle: Bundle = .main) throws -> [SafetyCategory] {
        let data = try resourceData(named: "safety_checklist", bundle: bundle)
        return try decodeSafetyCategories(from: data)
    }

    func decodeSafetyCategories(from data: Data) throws -> [SafetyCategory] {
        let catalog = try JSONDecoder().decode(SafetyCatalog.self, from: data)
        guard !catalog.categories.isEmpty else { throw MockDataError.emptyCatalog }
        return catalog.categories
    }

    func loadVisaArticles(bundle: Bundle = .main) throws -> [VisaArticle] {
        let data = try resourceData(named: "visa_articles", bundle: bundle)
        return try decodeVisaArticles(from: data)
    }

    func decodeVisaArticles(from data: Data) throws -> [VisaArticle] {
        let catalog = try JSONDecoder().decode(VisaArticleCatalog.self, from: data)
        guard !catalog.articles.isEmpty else { throw MockDataError.emptyCatalog }
        return catalog.articles
    }

    func loadBadges(bundle: Bundle = .main) throws -> [BadgeDefinition] {
        let data = try resourceData(named: "badges", bundle: bundle)
        return try decodeBadges(from: data)
    }

    func decodeBadges(from data: Data) throws -> [BadgeDefinition] {
        let catalog = try JSONDecoder().decode(BadgeCatalog.self, from: data)
        guard !catalog.badges.isEmpty else { throw MockDataError.emptyCatalog }
        return catalog.badges
    }

    private func resourceData(named name: String, bundle: Bundle) throws -> Data {
        if let url = bundle.url(forResource: name, withExtension: "json") {
            return try Data(contentsOf: url)
        }
        if let cachedURL = Self.offlineURL(for: name) {
            return try Data(contentsOf: cachedURL)
        }
        throw MockDataError.missingResource
    }

    private static func offlineURL(for resource: String) -> URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let url = base?.appendingPathComponent("OfflineCityPackage", isDirectory: true)
            .appendingPathComponent("\(resource).json")
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}
