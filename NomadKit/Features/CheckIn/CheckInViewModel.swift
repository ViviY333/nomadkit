import Foundation
import Observation

@MainActor
@Observable
final class CheckInViewModel {
    private(set) var cities: [CitySnapshot] = []
    private(set) var badges: [BadgeDefinition] = []
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
            badges = try service.loadBadges()
            errorMessage = nil
        } catch {
            cities = []
            badges = []
            errorMessage = error.localizedDescription
        }
    }
}
