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

        // Theme strip dragged open.
        let card = app.scrollViews.firstMatch
        card.swipeLeft()
        sleep(1)
        capture("02-theme-strip-open")

        app.staticTexts["Capture & shortcuts"].tap()
        XCTAssertTrue(app.navigationBars["Capture"].waitForExistence(timeout: 5))
        sleep(1)
        capture("03-capture")

        app.navigationBars["Capture"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.staticTexts["Bank SMS"].tap()
        XCTAssertTrue(app.navigationBars["Bank SMS"].waitForExistence(timeout: 5))
        sleep(1)
        capture("04-bank-sms")
    }
}
