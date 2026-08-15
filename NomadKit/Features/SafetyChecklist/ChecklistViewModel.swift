import Foundation
import Observation

@MainActor
@Observable
final class ChecklistViewModel {
    private(set) var categories: [SafetyCategory] = []
    private(set) var cities: [CitySnapshot] = []
    private(set) var errorMessage: String?

    private let service: MockDataService

    init(service: MockDataService = MockDataService()) {
        self.service = service
        load()
    }

    var totalItemCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }

    func city(id: String) -> CitySnapshot? {
        cities.first(where: { $0.id == id }) ?? cities.first
    }

    func load() {
        do {
            categories = try service.loadSafetyCategories()
            cities = try service.loadCities()
            errorMessage = nil
        } catch {
            categories = []
            cities = []
            errorMessage = error.localizedDescription
        }
    }
}
