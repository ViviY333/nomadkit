import XCTest
@testable import NomadKit

@MainActor
final class NomadKitTests: XCTestCase {
    func testCityCatalogDecodesBundledData() throws {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "cities", withExtension: "json"))
        let data = try Data(contentsOf: url)

        let cities = try MockDataService().decodeCities(from: data)

        XCTAssertEqual(cities.count, 3)
        XCTAssertEqual(cities.first?.id, "chiang-mai")
        XCTAssertEqual(cities.first?.moments.count, 3)
    }

    func testTravelCountdownIncludesEntryDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let entryDate = try XCTUnwrap(ISO8601DayFormatter.date(from: "2026-07-10"))
        let today = try XCTUnwrap(ISO8601DayFormatter.date(from: "2026-07-16"))
        let countdown = TravelCountdown(entryDate: entryDate, allowedStayDays: 30)

        let departure = try XCTUnwrap(countdown.latestDeparture(using: calendar))

        XCTAssertEqual(departure, ISO8601DayFormatter.date(from: "2026-08-08"))
        XCTAssertEqual(countdown.remainingDays(on: today, using: calendar), 23)
    }

    func testSafetyAndBadgeCatalogsDecode() throws {
        let bundle = Bundle(for: Self.self)
        let safetyURL = try XCTUnwrap(bundle.url(forResource: "safety_checklist", withExtension: "json"))
        let visaURL = try XCTUnwrap(bundle.url(forResource: "visa_articles", withExtension: "json"))
        let badgeURL = try XCTUnwrap(bundle.url(forResource: "badges", withExtension: "json"))

        let categories = try MockDataService().decodeSafetyCategories(from: Data(contentsOf: safetyURL))
        let visaArticles = try MockDataService().decodeVisaArticles(from: Data(contentsOf: visaURL))
        let badges = try MockDataService().decodeBadges(from: Data(contentsOf: badgeURL))

        XCTAssertEqual(categories.count, 8)
        XCTAssertTrue(categories.allSatisfy { !$0.items.isEmpty })
        XCTAssertEqual(visaArticles.map(\.id), [
            "thailand-dtv",
            "japan-digital-nomad",
            "korea-workcation-f1d",
            "portugal-digital-nomad",
            "spain-digital-nomad",
            "croatia-digital-nomad",
            "colombia-digital-nomad",
            "brazil-digital-nomad"
        ])
        XCTAssertTrue(visaArticles.allSatisfy {
            !$0.countryCode.isEmpty && !$0.sections.isEmpty && !$0.sources.isEmpty
        })
        XCTAssertEqual(badges.count, 6)
    }

    func testUserDataPersistsChecklistAndCheckIn() throws {
        let suiteName = "NomadKitTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let bundle = Bundle(for: Self.self)
        let cityURL = try XCTUnwrap(bundle.url(forResource: "cities", withExtension: "json"))
        let badgeURL = try XCTUnwrap(bundle.url(forResource: "badges", withExtension: "json"))
        let city = try XCTUnwrap(MockDataService().decodeCities(from: Data(contentsOf: cityURL)).first)
        let firstBadge = try XCTUnwrap(MockDataService().decodeBadges(from: Data(contentsOf: badgeURL)).first)

        let store = UserDataStore(defaults: defaults)
        store.profileDisplayName = "Yang"
        store.toggleSafetyItem("insurance-policy-offline")
        store.toggleWorkspaceFavorite(cityID: city.id, workspaceID: "punspace")
        store.toggleChannelFavorite(cityID: city.id, channelID: "connectivity")
        XCTAssertTrue(store.checkIn(city: city))
        XCTAssertFalse(store.checkIn(city: city))

        let restored = UserDataStore(defaults: defaults)
        XCTAssertTrue(restored.isSafetyItemCompleted("insurance-policy-offline"))
        XCTAssertEqual(restored.travelStats.cityCount, 1)
        XCTAssertEqual(restored.travelStats.totalDays, city.arrivalDay)
        XCTAssertTrue(restored.isBadgeUnlocked(firstBadge))
        XCTAssertTrue(restored.isWorkspaceFavorite(cityID: city.id, workspaceID: "punspace"))
        XCTAssertTrue(restored.isChannelFavorite(cityID: city.id, channelID: "connectivity"))
        XCTAssertEqual(restored.favoriteCount, 2)
        XCTAssertEqual(restored.profileDisplayName, "Yang")
    }

    func testUserDataPersistsProfileSettingsAndClearsLocalData() throws {
        try XCTSkipIf(ProcessInfo.processInfo.arguments.contains("-onboarding-reset"), "Debug reset arguments intentionally clear passport settings on initialization")
        let suiteName = "NomadKitProfileTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDataStore(defaults: defaults)
        store.profileDisplayName = "Nomad"
        store.passportNationality = "JP"
        store.selectedCityID = "taipei"
        store.currentCountryCode = "TW"
        store.currentCityName = "Taipei"
        store.currentDistrictName = "Xinyi District"
        store.currentLatitude = 25.033
        store.currentLongitude = 121.5654
        store.currentStayStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        store.allowedStayUntil = Date(timeIntervalSince1970: 1_701_000_000)
        store.preferredLanguageCode = "en"
        store.profileAvatarData = Data([1, 2, 3])

        let restored = UserDataStore(defaults: defaults)
        XCTAssertEqual(restored.profileDisplayName, "Nomad")
        XCTAssertEqual(restored.passportNationality, "JP")
        XCTAssertEqual(restored.selectedCityID, "taipei")
        XCTAssertEqual(restored.currentCountryCode, "TW")
        XCTAssertEqual(restored.currentCityName, "Taipei")
        XCTAssertEqual(restored.currentDistrictName, "Xinyi District")
        XCTAssertEqual(restored.currentLatitude, 25.033)
        XCTAssertEqual(restored.currentLongitude, 121.5654)
        XCTAssertEqual(restored.currentStayStartedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(restored.allowedStayUntil, Date(timeIntervalSince1970: 1_701_000_000))
        XCTAssertEqual(restored.preferredLanguageCode, "en")
        XCTAssertEqual(restored.profileAvatarData, Data([1, 2, 3]))

        restored.clearLocalData()
        XCTAssertEqual(restored.profileDisplayName, "")
        XCTAssertEqual(restored.passportNationality, "CN")
        XCTAssertEqual(restored.selectedCityID, "chiang-mai")
        XCTAssertEqual(restored.currentCountryCode, "TH")
        XCTAssertEqual(restored.currentCityName, "Chiang Mai")
        XCTAssertEqual(restored.currentDistrictName, "")
        XCTAssertNil(restored.currentLatitude)
        XCTAssertNil(restored.currentLongitude)
        XCTAssertNil(restored.currentStayStartedAt)
        XCTAssertNil(restored.allowedStayUntil)
        XCTAssertEqual(restored.preferredLanguageCode, "")
        XCTAssertNil(restored.profileAvatarData)
    }

    func testPassportImageRendersAtStoryResolution() throws {
        let content = PassportShareContent(
            travelerName: "Yang",
            cityNames: ["清迈", "曼谷", "台北"],
            stats: TravelStats(cityCount: 3, countryCount: 2, totalDays: 48),
            badgeCount: 3,
            generatedAt: try XCTUnwrap(ISO8601DayFormatter.date(from: "2026-07-19"))
        )

        let image = try XCTUnwrap(PassportImageRenderer.render(content: content))
        let cgImage = try XCTUnwrap(image.cgImage)

        XCTAssertEqual(cgImage.width, Int(PassportImageRenderer.outputSize.width))
        XCTAssertEqual(cgImage.height, Int(PassportImageRenderer.outputSize.height))

        let attachment = XCTAttachment(image: image)
        attachment.name = "passport-share-image"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testRecordedPlacesDriveCountryStatsAndReconcileLegacyCountries() throws {
        let suiteName = "NomadKitPlaceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDataStore(defaults: defaults)
        store.recordVisitedCountries(["FR", "DE"])
        XCTAssertEqual(store.travelStats.cityCount, 0)
        XCTAssertEqual(store.travelStats.countryCount, 2)
        XCTAssertEqual(store.recordedCountryCodes, ["DE", "FR"])

        store.recordVisitedCountries(["FR"])
        XCTAssertEqual(store.travelStats.countryCount, 1)
        XCTAssertEqual(store.recordedCountryCodes, ["FR"])

        let city = try XCTUnwrap(MockDataService().loadCities().first)
        XCTAssertTrue(store.checkIn(city: city))
        XCTAssertEqual(store.travelStats.cityCount, 1)
        XCTAssertEqual(store.travelStats.countryCount, 2)
        XCTAssertEqual(store.visits.first(where: { $0.cityID == city.id })?.countryID, "TH")
    }

    func testManualBeijingPlaceDrivesChinaMarkerStatsAndStamp() throws {
        let suiteName = "NomadKitBeijingPlaceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDataStore(defaults: defaults)
        XCTAssertTrue(store.addPlace(
            cityID: "manual-TH-beijing",
            cityName: LocalizedCopy(zhHans: "北京", en: "Beijing"),
            countryCode: "TH",
            countryName: CountryCatalog.name(for: "TH"),
            latitude: 39.9042,
            longitude: 116.4074,
            source: .manual
        ))
        XCTAssertTrue(store.addPlace(
            cityID: "manual-CN-beijing",
            cityName: LocalizedCopy(zhHans: "北京", en: "Beijing"),
            countryCode: "CN",
            countryName: CountryCatalog.name(for: "CN"),
            latitude: 39.9042,
            longitude: 116.4074,
            source: .manual
        ))

        let visit = try XCTUnwrap(store.visits.first)
        XCTAssertEqual(store.visits.count, 1)
        XCTAssertEqual(visit.countryID, "CN")
        XCTAssertEqual(visit.coordinate?.latitude, 39.9042)
        XCTAssertEqual(store.travelStats, TravelStats(cityCount: 1, countryCount: 1, totalDays: 1))
        XCTAssertEqual(CountryCatalog.stampAsset(for: visit.countryID), "StampCN")
    }
}
