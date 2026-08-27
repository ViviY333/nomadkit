import XCTest

final class NomadKitUITests: XCTestCase {
    func testEnglishCoreSurfacesContainNoChineseCopy() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-user.preferredLanguageCode", "en", "-subscription-pro"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Nomad Kit"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "早上好", "晚上好")).firstMatch.exists)

        app.buttons["Open profile and settings"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        XCTAssertFalse(app.staticTexts["城市目录数据来自 GeoNames"].exists)
        app.buttons["Close settings"].tap()

        app.buttons["Checklist"].tap()
        XCTAssertTrue(app.buttons["checklist.tool.Timezone"].waitForExistence(timeout: 3))
        app.buttons["checklist.tool.Timezone"].tap()
        XCTAssertTrue(app.staticTexts["Timezone"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "今天")).firstMatch.exists)

        app.terminate()
        app.launchArguments = ["-ui-testing-reset", "-user.preferredLanguageCode", "en", "-subscription-pro", "-show-nomad-map"]
        app.launch()
        XCTAssertTrue(app.buttons["Add a visited place"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["足迹"].exists)
        app.buttons["Add a visited place"].tap()
        XCTAssertTrue(app.navigationBars["Add places"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.navigationBars["添加地点"].exists)
        XCTAssertFalse(app.staticTexts["手动添加"].exists)
    }

    func testSubscriptionPaywallCanContinueWithFreeVersion() {
        let app = XCUIApplication()
        app.launchArguments = ["-show-subscription-paywall", "-user.preferredLanguageCode", "en"]
        app.launch()

        XCTAssertTrue(app.staticTexts["subscription.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["subscription.title"].label, "Go further with Pro")
        XCTAssertTrue(app.buttons["subscription.plan.annual"].exists)
        XCTAssertTrue(app.buttons["subscription.plan.monthly"].exists)
        XCTAssertFalse(app.staticTexts["Prices are loaded securely from the App Store."].exists)
        XCTAssertTrue(app.buttons["subscription.restore"].exists)
        let continueFree = app.buttons["subscription.continueFree"]
        XCTAssertTrue(continueFree.exists)
        attachScreenshot(named: "subscription-paywall-en")
        continueFree.tap()
        XCTAssertFalse(app.staticTexts["subscription.title"].waitForExistence(timeout: 1))
    }

    func testSubscriptionPaywallUsesSimplifiedChinese() {
        let app = XCUIApplication()
        app.launchArguments = ["-show-subscription-paywall", "-subscription-language-zh-Hans"]
        app.launch()

        XCTAssertTrue(app.staticTexts["subscription.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["subscription.title"].label, "让下一站也准备周全")
        XCTAssertTrue(app.buttons["subscription.plan.annual"].exists)
        XCTAssertTrue(app.buttons["subscription.plan.monthly"].exists)
        XCTAssertTrue(app.buttons["subscription.continueFree"].exists)
        attachScreenshot(named: "subscription-paywall-zh-Hans")
    }

    func testPreparingOnboardingSkipsVisitedCountries() {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding-reset", "-location-testing-stub", "-AppleLanguages", "(zh-Hans)"]
        app.launch()

        XCTAssertTrue(app.staticTexts["怎么描述你现在的阶段\n比较合适"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.52))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.52)))
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["下一站想去哪个国家？"].waitForExistence(timeout: 2))
        let thailand = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "泰国")).firstMatch
        XCTAssertTrue(thailand.waitForExistence(timeout: 2))
        thailand.tap()
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["预计什么时候出发？"].waitForExistence(timeout: 2))
        app.buttons["继续"].tap()
        XCTAssertTrue(app.staticTexts["现在什么对你\n最有用？"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["进入我的旅居首页"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["你去过哪些地方游民？"].exists)
        app.buttons["进入我的旅居首页"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["subscription.title"].exists)
    }

    func testChecklistSettingsAndCheckInFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-subscription-pro", "-user.preferredLanguageCode", "zh-Hans"]
        app.launch()

        app.buttons["清单"].tap()
        XCTAssertTrue(app.staticTexts["旅行清单"].waitForExistence(timeout: 3))
        attachScreenshot(named: "checklist-home")

        let insurance = app.buttons["checklist.tool.Insurance"]
        XCTAssertTrue(insurance.waitForExistence(timeout: 2))
        insurance.tap()
        XCTAssertTrue(app.staticTexts["数字游民保险"].waitForExistence(timeout: 2))
        attachScreenshot(named: "checklist-detail")

        app.buttons["打开我的与设置"].tap()
        XCTAssertTrue(app.staticTexts["设置"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["当前地点"].exists)
        attachScreenshot(named: "settings-sync")
        app.buttons["关闭设置"].tap()

        app.buttons["打卡"].tap()
        XCTAssertTrue(app.buttons["添加去过的地点"].waitForExistence(timeout: 4))
        attachScreenshot(named: "checkin-before")
    }

    func testProQuickToolPresentsPaywallForFreeUser() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-user.preferredLanguageCode", "zh-Hans"]
        app.launch()

        app.buttons["清单"].tap()
        let insurance = app.buttons["checklist.tool.Insurance"]
        XCTAssertTrue(insurance.waitForExistence(timeout: 3))
        insurance.tap()

        XCTAssertTrue(app.staticTexts["subscription.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["subscription.title"].label, "让下一站也准备周全")
    }

    func testVisaLibraryAndThailandArticle() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-AppleLanguages", "(zh-Hans)", "-subscription-language-zh-Hans", "-user.preferredLanguageCode", "zh-Hans"]
        app.launch()

        app.buttons["清单"].tap()
        XCTAssertTrue(app.staticTexts["旅行清单"].waitForExistence(timeout: 3))

        let visa = app.buttons["checklist.visa"]
        XCTAssertTrue(visa.waitForExistence(timeout: 2))
        visa.tap()
        XCTAssertTrue(app.navigationBars["数字游民签证"].waitForExistence(timeout: 2))
        attachScreenshot(named: "visa-library")

        let thailandDTV = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DTV")).firstMatch
        XCTAssertTrue(thailandDTV.waitForExistence(timeout: 2))
        thailandDTV.tap()
        XCTAssertTrue(app.navigationBars["泰国"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["5 年有效，不等于一次住 5 年"].waitForExistence(timeout: 2))
        let assessmentEntry = app.buttons["visa.assessment.entry"]
        XCTAssertTrue(assessmentEntry.waitForExistence(timeout: 2))
        assessmentEntry.tap()
        XCTAssertTrue(app.staticTexts["subscription.title"].waitForExistence(timeout: 3))
        attachScreenshot(named: "visa-thailand-article")
    }

    func testPackingChecklistSupportsAddingDeletingAndEnglishLocalization() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-user.preferredLanguageCode", "zh-Hans"]
        app.launch()

        app.buttons["清单"].tap()
        XCTAssertTrue(app.staticTexts["旅行清单"].waitForExistence(timeout: 3))
        app.buttons["旅行清单"].tap()

        let documents = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "证件资料"))
            .firstMatch
        for _ in 0..<6 where !documents.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52)))
        }
        XCTAssertTrue(documents.waitForExistence(timeout: 2))
        documents.tap()

        app.buttons["添加物品"].tap()
        let itemName = app.textFields["物品名称"]
        XCTAssertTrue(itemName.waitForExistence(timeout: 2))
        itemName.typeText("充电宝")
        app.buttons["添加"].tap()
        XCTAssertTrue(app.staticTexts["充电宝"].waitForExistence(timeout: 2))

        app.buttons["充电宝"].swipeLeft()
        XCTAssertTrue(app.buttons["删除"].waitForExistence(timeout: 2))
        app.buttons["删除"].tap()
        XCTAssertFalse(app.staticTexts["充电宝"].exists)

        app.terminate()
        app.launchArguments = ["-ui-testing-reset", "-user.preferredLanguageCode", "en"]
        app.launch()
        app.buttons["Checklist"].tap()
        XCTAssertTrue(app.staticTexts["Travel Checklist"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Documents"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "件")).firstMatch.exists)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
