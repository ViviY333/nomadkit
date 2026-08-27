import XCTest
import StoreKit
import StoreKitTest
@testable import NomadKit

@MainActor
final class NomadKitTests: XCTestCase {
    func testStoreKitConfigurationMatchesProductionCatalog() throws {
        let configurationURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "NomadKit", withExtension: "storekit"))
        _ = try SKTestSession(contentsOf: configurationURL)
        let data = try Data(contentsOf: configurationURL)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(root["subscriptionGroups"] as? [[String: Any]])
        let group = try XCTUnwrap(groups.first)
        let subscriptions = try XCTUnwrap(group["subscriptions"] as? [[String: Any]])
        let monthly = try XCTUnwrap(subscriptions.first { $0["productID"] as? String == SubscriptionProductID.monthly })
        let annual = try XCTUnwrap(subscriptions.first { $0["productID"] as? String == SubscriptionProductID.annual })
        let annualOffer = try XCTUnwrap(annual["introductoryOffer"] as? [String: Any])

        XCTAssertEqual(monthly["displayPrice"] as? String, "2.99")
        XCTAssertEqual(monthly["recurringSubscriptionPeriod"] as? String, "P1M")
        XCTAssertEqual(annual["displayPrice"] as? String, "19.99")
        XCTAssertEqual(annual["recurringSubscriptionPeriod"] as? String, "P1Y")
        XCTAssertEqual(annualOffer["paymentMode"] as? String, "FreeTrial")
        XCTAssertEqual(annualOffer["subscriptionPeriod"] as? String, "P3D")
        XCTAssertEqual(monthly["groupNumber"] as? Int, annual["groupNumber"] as? Int)
    }

    func testSubscriptionAnalyticsPersistsAggregateEventCounts() throws {
        let suiteName = "NomadKitSubscriptionAnalyticsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let analytics = SubscriptionAnalytics(defaults: defaults)

        analytics.track(.paywallViewed, entryPoint: .quickTool)
        analytics.track(.paywallViewed, entryPoint: .settings)

        XCTAssertEqual(analytics.count(for: .paywallViewed), 2)
    }

    func testCityCatalogDecodesBundledData() throws {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "cities", withExtension: "json"))
        let data = try Data(contentsOf: url)

        let cities = try MockDataService().decodeCities(from: data)

        XCTAssertEqual(cities.count, 3)
        XCTAssertEqual(cities.first?.id, "chiang-mai")
        XCTAssertEqual(cities.first?.moments.count, 3)
    }

    func testGlobalCityDirectorySupportsFilteringSearchAndCoordinates() throws {
        let directory = CityDirectory(bundle: Bundle(for: Self.self))
        XCTAssertGreaterThan(directory.cities.count, 60_000)

        let thailand = directory.cities(for: "TH")
        XCTAssertFalse(thailand.isEmpty)
        XCTAssertEqual(thailand.first?.countryCode, "TH")
        XCTAssertGreaterThanOrEqual(thailand.first?.population ?? 0, thailand.dropFirst().first?.population ?? 0)

        let chiangMai = directory.search("chiang mai", countryCode: "TH")
        XCTAssertTrue(chiangMai.contains { $0.asciiName.localizedCaseInsensitiveCompare("Chiang Mai") == .orderedSame })
        let accented = directory.search("Sao Paulo", countryCode: "BR")
        XCTAssertTrue(accented.contains { $0.asciiName.localizedCaseInsensitiveCompare("Sao Paulo") == .orderedSame })

        for city in directory.cities(for: "US", limit: 20) {
            XCTAssertGreaterThanOrEqual(city.latitude, -90)
            XCTAssertLessThanOrEqual(city.latitude, 90)
            XCTAssertGreaterThanOrEqual(city.longitude, -180)
            XCTAssertLessThanOrEqual(city.longitude, 180)
        }
    }

    func testKeyLocalizedCopyUsesRequestedLanguage() {
        let copy = LocalizedCopy(zhHans: "今天 %@ 小时", en: "Today %@ h")
        XCTAssertEqual(copy.value(for: Locale(identifier: "en")), "Today %@ h")
        XCTAssertEqual(copy.value(for: Locale(identifier: "zh-Hans")), "今天 %@ 小时")
        XCTAssertEqual(appLocalized("timezone.relative.format", locale: Locale(identifier: "en")), "Today %@ h")
        XCTAssertEqual(appLocalized("timezone.relative.format", locale: Locale(identifier: "zh-Hans")), "今天 %@ 小时")
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
        store.residencyCountryCode = "TW"
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
        XCTAssertEqual(restored.residencyCountryCode, "TW")
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
        XCTAssertEqual(restored.residencyCountryCode, "")
        XCTAssertEqual(restored.preferredLanguageCode, "")
        XCTAssertNil(restored.profileAvatarData)
    }

    func testAppearancePreferenceMigratesLegacyDarkMode() throws {
        let suiteName = "NomadKitAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "user.prefersDarkMode")
        let store = UserDataStore(defaults: defaults)
        XCTAssertEqual(store.appearancePreference, .dark)

        store.appearancePreference = .system
        let restored = UserDataStore(defaults: defaults)
        XCTAssertEqual(restored.appearancePreference, .system)
    }

    func testResidencyCountryMigratesFromExistingStay() throws {
        try XCTSkipIf(ProcessInfo.processInfo.arguments.contains("-onboarding-reset"), "Debug reset arguments intentionally clear stay settings on initialization")
        let suiteName = "NomadKitResidencyMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("JP", forKey: "user.currentCountryCode")
        defaults.set(Date(timeIntervalSince1970: 1_700_000_000), forKey: "user.currentStayStartedAt")
        defaults.set(Date(timeIntervalSince1970: 1_701_000_000), forKey: "user.allowedStayUntil")

        let store = UserDataStore(defaults: defaults)

        XCTAssertEqual(store.residencyCountryCode, "JP")
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
        XCTAssertEqual(store.travelStats.worldCoveragePercent, 1)
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
        XCTAssertEqual(store.travelStats.worldCoveragePercent, 1)
        XCTAssertEqual(CountryCatalog.stampAsset(for: visit.countryID), "StampCN")
    }

    func testStampAssetsUseISOCodeNamingConvention() {
        XCTAssertEqual(CountryCatalog.stampAsset(for: "tw"), "StampTW")
        XCTAssertEqual(CountryCatalog.stampAsset(for: " BD "), "StampBD")
        XCTAssertNil(CountryCatalog.stampAsset(for: "invalid"))
        XCTAssertEqual(CountryCatalog.name(for: "AL").en, "Albania")
    }

    func testToshikoVisaOutcomesAreNormalized() {
        XCTAssertEqual(VisaRequirementKind(toshikoOutcome: "no_visa"), .visaFree)
        XCTAssertEqual(VisaRequirementKind(toshikoOutcome: "visa_waiver"), .visaFree)
        XCTAssertEqual(VisaRequirementKind(toshikoOutcome: "free_movement"), .visaFree)
        XCTAssertEqual(VisaRequirementKind(toshikoOutcome: "keta_exempt"), .visaFree)
        XCTAssertEqual(VisaRequirementKind(toshikoOutcome: "esta"), .eTA)
        XCTAssertEqual(VisaRequirementKind(toshikoOutcome: "nzeta"), .eTA)
        XCTAssertEqual(VisaRequirementKind(toshikoOutcome: "evisitor"), .eTA)
    }

    func testPassportIndexStatusesAreNormalized() {
        XCTAssertEqual(VisaRequirementKind(passportIndexStatus: "visa free"), .visaFree)
        XCTAssertEqual(VisaRequirementKind(passportIndexStatus: "eta"), .eTA)
        XCTAssertEqual(VisaRequirementKind(passportIndexStatus: "e-visa"), .eVisa)
        XCTAssertEqual(VisaRequirementKind(passportIndexStatus: "visa on arrival"), .visaOnArrival)
        XCTAssertEqual(VisaRequirementKind(passportIndexStatus: "visa required"), .visaRequired)
        XCTAssertEqual(VisaRequirementKind(passportIndexStatus: "no admission"), .check)
    }
}
