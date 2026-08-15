import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private(set) var cities: [CitySnapshot] = []
    private(set) var errorMessage: String?

    private let service: MockDataService

    init(service: MockDataService = MockDataService()) {
        self.service = service
        load()
    }

    func city(id: String) -> CitySnapshot? {
        cities.first(where: { $0.id == id }) ?? cities.first
    }

    func load() {
        do {
            cities = try service.loadCities()
            errorMessage = nil
        } catch {
            cities = []
            errorMessage = error.localizedDescription
        }
    }
}
