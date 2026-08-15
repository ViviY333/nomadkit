@preconcurrency import CoreLocation
import Foundation
import MapKit
import Observation

struct ResolvedPlace: Equatable {
    let city: String
    let district: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
}

private enum LocationRequestError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .servicesDisabled: "Location Services are turned off. Enable them in Settings and try again."
        case .permissionDenied: "Location permission is denied. Enable Location Services for NomadKit in Settings."
        case .unavailable: "Your current location is temporarily unavailable. Try again or enter a city manually."
        }
    }
}

@MainActor
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var transientFailureCount = 0
    private var cachedAuthorizationStatus: CLAuthorizationStatus?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentPlace() async throws -> ResolvedPlace {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-location-testing-stub") {
            return ResolvedPlace(city: "Chiang Mai", district: "Mueang Chiang Mai", countryCode: "TH", latitude: 18.7883, longitude: 98.9853)
        }
#endif
        let location = try await currentLocation()
        let marks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let mark = marks.first,
              let city = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea,
              let countryCode = mark.isoCountryCode else {
            throw CLError(.geocodeFoundNoResult)
        }
        return ResolvedPlace(
            city: city,
            district: Self.district(from: mark, excluding: city),
            countryCode: countryCode,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    var needsSettingsToGrantLocation: Bool {
        cachedAuthorizationStatus == .denied || cachedAuthorizationStatus == .restricted
    }

    func resolve(city: String, countryName: String) async throws -> ResolvedPlace {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(city), \(countryName)"
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw CLError(.geocodeFoundNoResult) }
        let coordinate = item.placemark.coordinate
        return ResolvedPlace(
            city: item.placemark.locality ?? city,
            district: Self.district(from: item.placemark, excluding: city),
            countryCode: item.placemark.countryCode ?? "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private func currentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.transientFailureCount = 0
            requestLocationIfAuthorized()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Core Location delivers the current state here; caching it avoids synchronous
        // authorization-status IPC from the main thread during rendering or requests.
        cachedAuthorizationStatus = manager.authorizationStatus
        requestLocationIfAuthorized()
    }

    private func requestLocationIfAuthorized() {
        guard continuation != nil, let cachedAuthorizationStatus else { return }

        switch cachedAuthorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let cached = manager.location,
               abs(cached.timestamp.timeIntervalSinceNow) < 300,
               cached.horizontalAccuracy >= 0 {
                continuation?.resume(returning: cached)
                continuation = nil
                return
            }
            if continuation != nil { manager.requestLocation() }
        case .denied, .restricted:
            continuation?.resume(throwing: LocationRequestError.permissionDenied)
            continuation = nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            continuation?.resume(throwing: LocationRequestError.unavailable)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .locationUnknown {
            transientFailureCount += 1
            guard transientFailureCount <= 2 else {
                continuation?.resume(throwing: LocationRequestError.unavailable)
                continuation = nil
                return
            }
            manager.requestLocation()
            return
        }
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private static func district(from placemark: CLPlacemark, excluding city: String) -> String {
        [placemark.subLocality, placemark.subAdministrativeArea, placemark.administrativeArea]
            .compactMap { $0 }
            .first { $0.localizedCaseInsensitiveCompare(city) != .orderedSame } ?? ""
    }

    private static func district(from placemark: MKPlacemark, excluding city: String) -> String {
        [placemark.subLocality, placemark.subAdministrativeArea, placemark.administrativeArea]
            .compactMap { $0 }
            .first { $0.localizedCaseInsensitiveCompare(city) != .orderedSame } ?? ""
    }
}

extension LocationService: @MainActor CLLocationManagerDelegate {}

@MainActor
@Observable
final class UserDataStore {
    var onboardingCompleted: Bool {
        didSet {
            guard !ProcessInfo.processInfo.arguments.contains("-onboarding-reset") else { return }
            defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted)
        }
    }

    var passportNationality: String {
        didSet { defaults.set(passportNationality, forKey: Keys.passportNationality) }
    }

    var passportNationalities: [String] {
        didSet { defaults.set(passportNationalities, forKey: Keys.passportNationalities) }
    }

    var plannedCountryCodes: [String] {
        didSet { defaults.set(plannedCountryCodes, forKey: Keys.plannedCountryCodes) }
    }

    var preferredComponentIDs: [String] {
        didSet { defaults.set(preferredComponentIDs, forKey: Keys.preferredComponentIDs) }
    }

    var visitedCountryCodes: [String] {
        didSet { defaults.set(visitedCountryCodes, forKey: Keys.visitedCountryCodes) }
    }

    var journeyStageID: String {
        didSet { defaults.set(journeyStageID, forKey: Keys.journeyStageID) }
    }

    var allowedStayUntil: Date? {
        didSet { defaults.set(allowedStayUntil, forKey: Keys.allowedStayUntil) }
    }

    var currentStayStartedAt: Date? {
        didSet { defaults.set(currentStayStartedAt, forKey: Keys.currentStayStartedAt) }
    }

    var selectedCityID: String {
        didSet { defaults.set(selectedCityID, forKey: Keys.selectedCityID) }
    }

    var currentCountryCode: String {
        didSet { defaults.set(currentCountryCode, forKey: Keys.currentCountryCode) }
    }

    var currentCityName: String {
        didSet { defaults.set(currentCityName, forKey: Keys.currentCityName) }
    }

    var currentDistrictName: String {
        didSet { defaults.set(currentDistrictName, forKey: Keys.currentDistrictName) }
    }

    var currentLatitude: Double? {
        didSet { defaults.set(currentLatitude, forKey: Keys.currentLatitude) }
    }

    var currentLongitude: Double? {
        didSet { defaults.set(currentLongitude, forKey: Keys.currentLongitude) }
    }

    var profileDisplayName: String {
        didSet { defaults.set(profileDisplayName, forKey: Keys.profileDisplayName) }
    }

    var preferredLanguageCode: String {
        didSet { defaults.set(preferredLanguageCode, forKey: Keys.preferredLanguageCode) }
    }

    var profileAvatarData: Data? {
        didSet { defaults.set(profileAvatarData, forKey: Keys.profileAvatarData) }
    }

    var usesCurrentLocation: Bool {
        didSet { defaults.set(usesCurrentLocation, forKey: Keys.usesCurrentLocation) }
    }

    var prefersDarkMode: Bool {
        didSet { defaults.set(prefersDarkMode, forKey: Keys.prefersDarkMode) }
    }

    var hasOfflineMapPackage: Bool {
        didSet { defaults.set(hasOfflineMapPackage, forKey: Keys.hasOfflineMapPackage) }
    }

    var offlineMapCityName: String {
        didSet { defaults.set(offlineMapCityName, forKey: Keys.offlineMapCityName) }
    }

    var appleUserIdentifier: String? {
        didSet { defaults.set(appleUserIdentifier, forKey: Keys.appleUserIdentifier) }
    }

    var appleAccountEmail: String? {
        didSet { defaults.set(appleAccountEmail, forKey: Keys.appleAccountEmail) }
    }

    var isSignedInWithApple: Bool {
        appleUserIdentifier?.isEmpty == false
    }

    private(set) var completedSafetyItemIDs: Set<String> {
        didSet { saveCompletedItems() }
    }

    private(set) var visits: [TravelVisit] {
        didSet { saveVisits() }
    }

    private(set) var favoriteWorkspaceKeys: Set<String> {
        didSet { saveFavorites(favoriteWorkspaceKeys, key: Keys.favoriteWorkspaceKeys) }
    }

    private(set) var favoriteChannelKeys: Set<String> {
        didSet { saveFavorites(favoriteChannelKeys, key: Keys.favoriteChannelKeys) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedPassportNationality = defaults.string(forKey: Keys.passportNationality) ?? "CN"
        var storedSelectedCityID = defaults.string(forKey: Keys.selectedCityID) ?? "chiang-mai"
        onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        passportNationality = storedPassportNationality
        passportNationalities = defaults.stringArray(forKey: Keys.passportNationalities) ?? [storedPassportNationality]
        plannedCountryCodes = defaults.stringArray(forKey: Keys.plannedCountryCodes) ?? []
        preferredComponentIDs = defaults.stringArray(forKey: Keys.preferredComponentIDs) ?? []
        visitedCountryCodes = defaults.stringArray(forKey: Keys.visitedCountryCodes) ?? []
        journeyStageID = defaults.string(forKey: Keys.journeyStageID) ?? ""
        allowedStayUntil = defaults.object(forKey: Keys.allowedStayUntil) as? Date
        currentStayStartedAt = defaults.object(forKey: Keys.currentStayStartedAt) as? Date
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-onboarding-reset") {
            defaults.removeObject(forKey: Keys.onboardingCompleted)
            defaults.removeObject(forKey: Keys.passportNationality)
            defaults.removeObject(forKey: Keys.passportNationalities)
            defaults.removeObject(forKey: Keys.plannedCountryCodes)
            defaults.removeObject(forKey: Keys.preferredComponentIDs)
            defaults.removeObject(forKey: Keys.visitedCountryCodes)
            defaults.removeObject(forKey: Keys.journeyStageID)
            defaults.removeObject(forKey: Keys.allowedStayUntil)
            defaults.removeObject(forKey: Keys.currentStayStartedAt)
            defaults.removeObject(forKey: Keys.currentCountryCode)
            defaults.removeObject(forKey: Keys.currentCityName)
            defaults.removeObject(forKey: Keys.currentDistrictName)
            defaults.removeObject(forKey: Keys.currentLatitude)
            defaults.removeObject(forKey: Keys.currentLongitude)
            onboardingCompleted = false
            passportNationality = "CN"
            passportNationalities = ["CN"]
            plannedCountryCodes = []
            preferredComponentIDs = []
            visitedCountryCodes = []
            journeyStageID = ""
            allowedStayUntil = nil
            currentStayStartedAt = nil
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") {
            onboardingCompleted = true
            defaults.removeObject(forKey: Keys.selectedCityID)
            defaults.removeObject(forKey: Keys.currentCountryCode)
            defaults.removeObject(forKey: Keys.currentCityName)
            defaults.removeObject(forKey: Keys.currentDistrictName)
            defaults.removeObject(forKey: Keys.currentLatitude)
            defaults.removeObject(forKey: Keys.currentLongitude)
            defaults.removeObject(forKey: Keys.profileDisplayName)
            defaults.removeObject(forKey: Keys.visits)
            defaults.removeObject(forKey: Keys.favoriteWorkspaceKeys)
            defaults.removeObject(forKey: Keys.favoriteChannelKeys)
            storedSelectedCityID = "chiang-mai"
        }
#endif
        selectedCityID = storedSelectedCityID
        currentCountryCode = defaults.string(forKey: Keys.currentCountryCode)
            ?? Self.countryCode(forCityID: storedSelectedCityID)
        currentCityName = defaults.string(forKey: Keys.currentCityName)
            ?? Self.cityName(forCityID: storedSelectedCityID)
        currentDistrictName = defaults.string(forKey: Keys.currentDistrictName) ?? ""
        currentLatitude = defaults.object(forKey: Keys.currentLatitude) as? Double
        currentLongitude = defaults.object(forKey: Keys.currentLongitude) as? Double
        profileDisplayName = defaults.string(forKey: Keys.profileDisplayName) ?? ""
        preferredLanguageCode = defaults.string(forKey: Keys.preferredLanguageCode) ?? ""
        profileAvatarData = defaults.data(forKey: Keys.profileAvatarData)
        usesCurrentLocation = defaults.bool(forKey: Keys.usesCurrentLocation)
        prefersDarkMode = defaults.bool(forKey: Keys.prefersDarkMode)
        hasOfflineMapPackage = defaults.bool(forKey: Keys.hasOfflineMapPackage)
        offlineMapCityName = defaults.string(forKey: Keys.offlineMapCityName) ?? ""
        appleUserIdentifier = defaults.string(forKey: Keys.appleUserIdentifier)
        appleAccountEmail = defaults.string(forKey: Keys.appleAccountEmail)
        completedSafetyItemIDs = Self.loadCompletedItems(from: defaults)
        visits = Self.loadVisits(from: defaults)
        favoriteWorkspaceKeys = Self.loadFavorites(from: defaults, key: Keys.favoriteWorkspaceKeys)
        favoriteChannelKeys = Self.loadFavorites(from: defaults, key: Keys.favoriteChannelKeys)
    }

    func toggleSafetyItem(_ itemID: String) {
        if completedSafetyItemIDs.contains(itemID) {
            completedSafetyItemIDs.remove(itemID)
        } else {
            completedSafetyItemIDs.insert(itemID)
        }
    }

    func clearLocalData() {
        let keys = [
            Keys.passportNationality, Keys.passportNationalities, Keys.plannedCountryCodes,
            Keys.preferredComponentIDs, Keys.visitedCountryCodes, Keys.journeyStageID,
            Keys.allowedStayUntil, Keys.currentStayStartedAt, Keys.selectedCityID, Keys.currentCountryCode, Keys.currentCityName,
            Keys.currentDistrictName,
            Keys.currentLatitude, Keys.currentLongitude, Keys.profileDisplayName,
            Keys.preferredLanguageCode,
            Keys.profileAvatarData, Keys.completedSafetyItemIDs, Keys.visits,
            Keys.favoriteWorkspaceKeys, Keys.favoriteChannelKeys,
            Keys.usesCurrentLocation, Keys.prefersDarkMode, Keys.hasOfflineMapPackage,
            Keys.offlineMapCityName, Keys.appleUserIdentifier, Keys.appleAccountEmail
        ]
        keys.forEach(defaults.removeObject(forKey:))

        passportNationality = "CN"
        passportNationalities = ["CN"]
        plannedCountryCodes = []
        preferredComponentIDs = []
        visitedCountryCodes = []
        journeyStageID = ""
        allowedStayUntil = nil
        currentStayStartedAt = nil
        selectedCityID = "chiang-mai"
        currentCountryCode = "TH"
        currentCityName = "Chiang Mai"
        currentDistrictName = ""
        currentLatitude = nil
        currentLongitude = nil
        profileDisplayName = ""
        preferredLanguageCode = ""
        profileAvatarData = nil
        usesCurrentLocation = false
        prefersDarkMode = false
        hasOfflineMapPackage = false
        offlineMapCityName = ""
        appleUserIdentifier = nil
        appleAccountEmail = nil
        completedSafetyItemIDs = []
        visits = []
        favoriteWorkspaceKeys = []
        favoriteChannelKeys = []
    }

    func isSafetyItemCompleted(_ itemID: String) -> Bool {
        completedSafetyItemIDs.contains(itemID)
    }

    func completedCount(in category: SafetyCategory) -> Int {
        category.items.lazy.filter { self.completedSafetyItemIDs.contains($0.id) }.count
    }

    func isCheckedIn(cityID: String) -> Bool {
        visits.contains { $0.cityID == cityID }
    }

    @discardableResult
    func checkIn(city: CitySnapshot, date: Date = .now) -> Bool {
        guard !isCheckedIn(cityID: city.id) else { return false }
        visits.append(
            TravelVisit(
                id: UUID(),
                cityID: city.id,
                cityName: city.name,
                countryID: city.country.en,
                days: max(city.arrivalDay, 1),
                checkedInAt: date
            )
        )
        return true
    }

    func removeCheckIn(cityID: String) {
        visits.removeAll { $0.cityID == cityID }
    }

    func toggleWorkspaceFavorite(cityID: String, workspaceID: String) {
        Self.toggleFavorite(Self.favoriteKey(cityID: cityID, itemID: workspaceID), in: &favoriteWorkspaceKeys)
    }

    func isWorkspaceFavorite(cityID: String, workspaceID: String) -> Bool {
        favoriteWorkspaceKeys.contains(Self.favoriteKey(cityID: cityID, itemID: workspaceID))
    }

    func toggleChannelFavorite(cityID: String, channelID: String) {
        Self.toggleFavorite(Self.favoriteKey(cityID: cityID, itemID: channelID), in: &favoriteChannelKeys)
    }

    func isChannelFavorite(cityID: String, channelID: String) -> Bool {
        favoriteChannelKeys.contains(Self.favoriteKey(cityID: cityID, itemID: channelID))
    }

    var favoriteCount: Int {
        favoriteWorkspaceKeys.count + favoriteChannelKeys.count
    }

    var travelStats: TravelStats {
        TravelStats(
            cityCount: Set(visits.map(\.cityID)).count,
            countryCount: Set(visits.map(\.countryID)).count,
            totalDays: visits.reduce(0) { $0 + $1.days }
        )
    }

    func isBadgeUnlocked(_ badge: BadgeDefinition) -> Bool {
        let value: Int
        switch badge.rule.metric {
        case .cityCount:
            value = travelStats.cityCount
        case .countryCount:
            value = travelStats.countryCount
        case .totalDays:
            value = travelStats.totalDays
        case .checklistCount:
            value = completedSafetyItemIDs.count
        }
        return value >= badge.rule.threshold
    }

    private func saveCompletedItems() {
        defaults.set(Array(completedSafetyItemIDs).sorted(), forKey: Keys.completedSafetyItemIDs)
    }

    private func saveVisits() {
        guard let data = try? JSONEncoder().encode(visits) else { return }
        defaults.set(data, forKey: Keys.visits)
    }

    private static func toggleFavorite(_ key: String, in favorites: inout Set<String>) {
        if favorites.contains(key) {
            favorites.remove(key)
        } else {
            favorites.insert(key)
        }
    }

    private func saveFavorites(_ favorites: Set<String>, key: String) {
        defaults.set(Array(favorites).sorted(), forKey: key)
    }

    private static func loadCompletedItems(from defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: Keys.completedSafetyItemIDs) ?? [])
    }

    private static func loadVisits(from defaults: UserDefaults) -> [TravelVisit] {
        guard let data = defaults.data(forKey: Keys.visits),
              let visits = try? JSONDecoder().decode([TravelVisit].self, from: data) else {
            return []
        }
        return visits
    }

    private static func loadFavorites(from defaults: UserDefaults, key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    nonisolated static func favoriteKey(cityID: String, itemID: String) -> String {
        "\(cityID)::\(itemID)"
    }

    func updateCurrentPlace(_ place: ResolvedPlace) {
        currentCityName = place.city
        currentDistrictName = place.district
        if !place.countryCode.isEmpty { currentCountryCode = place.countryCode.uppercased() }
        currentLatitude = place.latitude
        currentLongitude = place.longitude
        selectedCityID = Self.closestContentCityID(to: place)
    }

    var currentCoordinate: CLLocationCoordinate2D? {
        guard let currentLatitude, let currentLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: currentLatitude, longitude: currentLongitude)
    }

    private static func countryCode(forCityID cityID: String) -> String {
        switch cityID {
        case "taipei": "TW"
        default: "TH"
        }
    }

    private static func cityName(forCityID cityID: String) -> String {
        switch cityID {
        case "bangkok": "Bangkok"
        case "taipei": "Taipei"
        default: "Chiang Mai"
        }
    }

    private static func closestContentCityID(to place: ResolvedPlace) -> String {
        let supported = [
            ("chiang-mai", 18.7883, 98.9853),
            ("bangkok", 13.7563, 100.5018),
            ("taipei", 25.0330, 121.5654)
        ]
        return supported.min { lhs, rhs in
            hypot(place.latitude - lhs.1, place.longitude - lhs.2) < hypot(place.latitude - rhs.1, place.longitude - rhs.2)
        }?.0 ?? "chiang-mai"
    }

    private enum Keys {
        static let selectedCityID = "user.selectedCityID"
        static let currentCountryCode = "user.currentCountryCode"
        static let currentCityName = "user.currentCityName"
        static let currentDistrictName = "user.currentDistrictName"
        static let currentLatitude = "user.currentLatitude"
        static let currentLongitude = "user.currentLongitude"
        static let onboardingCompleted = "user.onboardingCompleted"
        static let passportNationality = "user.passportNationality"
        static let passportNationalities = "user.passportNationalities"
        static let plannedCountryCodes = "user.plannedCountryCodes"
        static let preferredComponentIDs = "user.preferredComponentIDs"
        static let visitedCountryCodes = "user.visitedCountryCodes"
        static let journeyStageID = "user.journeyStageID"
        static let allowedStayUntil = "user.allowedStayUntil"
        static let currentStayStartedAt = "user.currentStayStartedAt"
        static let profileDisplayName = "user.profileDisplayName"
        static let preferredLanguageCode = "user.preferredLanguageCode"
        static let profileAvatarData = "user.profileAvatarData"
        static let usesCurrentLocation = "user.usesCurrentLocation"
        static let prefersDarkMode = "user.prefersDarkMode"
        static let hasOfflineMapPackage = "user.hasOfflineMapPackage"
        static let offlineMapCityName = "user.offlineMapCityName"
        static let appleUserIdentifier = "user.appleUserIdentifier"
        static let appleAccountEmail = "user.appleAccountEmail"
        static let completedSafetyItemIDs = "user.completedSafetyItemIDs"
        static let visits = "user.travelVisits"
        static let favoriteWorkspaceKeys = "user.favoriteWorkspaceKeys"
        static let favoriteChannelKeys = "user.favoriteChannelKeys"
    }
}
