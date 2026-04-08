import XCTest

final class LyttejegerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "nb_NO", "-AppleLanguages", "(nb)"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppLaunches() throws {
        XCTAssertTrue(app.state == .runningForeground, "Appen skal kjøre i forgrunnen")
    }

    func testTabBarNavigation() throws {
        // Wait for splash screen to dismiss
        let queueTab = app.buttons["Kø"]
        XCTAssertTrue(queueTab.waitForExistence(timeout: 5), "Kø-fanen skal vises")
        queueTab.tap()

        // Queue view shows either episodes or empty state
        let emptyState = app.staticTexts["Ingen episoder i køen"]
        let clearButton = app.buttons["Tøm"]
        let found = emptyState.waitForExistence(timeout: 3) || clearButton.waitForExistence(timeout: 1)
        XCTAssertTrue(found, "Kø-visningen skal vise innhold etter navigasjon")
    }
}
