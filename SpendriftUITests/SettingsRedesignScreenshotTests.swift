import XCTest

final class SettingsRedesignScreenshotTests: SpendriftUITestBase {
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCaptureSettingsScreens() throws {
        navigateToSettings()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        sleep(1)
        capture("01-settings-main")

        app.staticTexts["Explore"].tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        sleep(1)
        capture("02-explore")

        app.staticTexts["Capture & shortcuts"].tap()
        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))
        sleep(1)
        capture("03-capture")

        app.navigationBars["Capture"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))

        app.staticTexts["See setup steps"].tap()
        XCTAssertTrue(app.navigationBars["Bank SMS"].waitForExistence(timeout: 5))
        sleep(1)
        capture("04-bank-sms")

        app.navigationBars["Bank SMS"].buttons.firstMatch.tap()
        app.navigationBars["Explore"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.staticTexts["Preferences"].tap()
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 5))
        app.scrollViews.firstMatch.swipeLeft()
        sleep(1)
        capture("05-preferences")
    }
}
