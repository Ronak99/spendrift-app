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
        XCTAssertTrue(app.staticTexts["Shout it out"].waitForExistence(timeout: 5))
        sleep(1)
        capture("02-explore")

        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Write it out"].waitForExistence(timeout: 5))
        sleep(1)
        capture("03-explore-write")

        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Import SMS"].waitForExistence(timeout: 5))
        sleep(1)
        capture("04-explore-sms")

        app.staticTexts["See setup steps"].tap()
        XCTAssertTrue(app.navigationBars["Bank SMS"].waitForExistence(timeout: 5))
        sleep(1)
        capture("05-bank-sms")

        app.navigationBars["Bank SMS"].buttons.firstMatch.tap()
        app.navigationBars["Explore"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.staticTexts["Preferences"].tap()
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 5))
        app.scrollViews.firstMatch.swipeLeft()
        sleep(1)
        capture("06-preferences")
    }
}
