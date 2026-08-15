import Foundation
import Observation

@MainActor
@Observable
final class VisaLibraryViewModel {
    private(set) var articles: [VisaArticle] = []
    private(set) var errorMessage: String?

    private let service: MockDataService

    init(service: MockDataService = MockDataService()) {
        self.service = service
        load()
    }

    func load() {
        do {
            articles = try service.loadVisaArticles()
            errorMessage = nil
        } catch {
            articles = []
            errorMessage = error.localizedDescription
        }
    }
}
