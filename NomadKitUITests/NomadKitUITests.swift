import XCTest

final class NomadKitUITests: XCTestCase {
    func testPreparingOnboardingSkipsVisitedCountries() {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding-reset", "-location-testing-stub", "-AppleLanguages", "(zh-Hans)"]
        app.launch()

        XCTAssertTrue(app.staticTexts["怎么描述你现在的阶段\n比较合适"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.52))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.52)))
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["获取并确认当前位置"].waitForExistence(timeout: 2))
        app.buttons["获取当前位置"].tap()
        app.buttons["确认位置"].tap()

        XCTAssertTrue(app.staticTexts["下一站想去哪个国家？"].waitForExistence(timeout: 2))
        let thailand = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "泰国")).firstMatch
        XCTAssertTrue(thailand.waitForExistence(timeout: 2))
        thailand.tap()
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["预计什么时候出发？"].waitForExistence(timeout: 2))
        app.buttons["继续"].tap()
        XCTAssertTrue(app.staticTexts["现在什么对你\n最有用？"].waitForExistence(timeout: 2))
        app.buttons["继续"].tap()
        XCTAssertTrue(app.staticTexts["出发需要的东西已经装好"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["你去过哪些地方游民？"].exists)
    }

    func testChecklistSettingsAndCheckInFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        app.buttons["清单"].tap()
        XCTAssertTrue(app.navigationBars["清单"].waitForExistence(timeout: 3))
        attachScreenshot(named: "checklist-home")

        let insurance = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "保险")).firstMatch
        XCTAssertTrue(insurance.waitForExistence(timeout: 2))
        insurance.tap()
        XCTAssertTrue(app.navigationBars["保险"].waitForExistence(timeout: 2))

        let firstItem = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "离线保存保单")).firstMatch
        XCTAssertTrue(firstItem.waitForExistence(timeout: 2))
        firstItem.tap()
        attachScreenshot(named: "checklist-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["打开我的与设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["数据与同步"].exists)
        attachScreenshot(named: "settings-sync")
        app.buttons["完成"].tap()

        app.buttons["打卡"].tap()
        XCTAssertTrue(app.staticTexts["记录真正生活过的城市"].waitForExistence(timeout: 2))
        attachScreenshot(named: "checkin-before")

        let checkInButton = app.buttons["标记“我来过这里”"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 2))
        checkInButton.tap()
        XCTAssertTrue(app.staticTexts["这座城市已收进护照"].waitForExistence(timeout: 2))
        attachScreenshot(named: "checkin-after")
    }

    func testVisaLibraryAndThailandArticle() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        app.buttons["清单"].tap()
        XCTAssertTrue(app.navigationBars["清单"].waitForExistence(timeout: 3))

        let visa = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "签证")).firstMatch
        XCTAssertTrue(visa.waitForExistence(timeout: 2))
        visa.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["签证"].waitForExistence(timeout: 2))
        attachScreenshot(named: "visa-library")

        let thailandDTV = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DTV")).firstMatch
        XCTAssertTrue(thailandDTV.waitForExistence(timeout: 2))
        thailandDTV.tap()
        XCTAssertTrue(app.navigationBars["泰国"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["5 年有效，不等于一次住 5 年"].waitForExistence(timeout: 2))
        attachScreenshot(named: "visa-thailand-article")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
