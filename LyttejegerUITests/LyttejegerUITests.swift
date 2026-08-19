import XCTest

@MainActor
final class LyttejegerUITests: XCTestCase {

    var app: XCUIApplication!

    // Async overrides adopt the class's MainActor isolation; the sync
    // *WithError variants stay nonisolated and cannot touch XCUI APIs
    // cleanly under strict concurrency.
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "nb_NO", "-AppleLanguages", "(nb)"]
        app.launch()
    }

    override func tearDown() async throws {
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

    func testMenuOpensAndCloses() throws {
        let menuButton = app.buttons["Meny"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Meny-knappen skal vises")
        menuButton.tap()

        let deleteRow = app.staticTexts["Slett alle data"]
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 5), "Menyen skal vise Slett alle data")

        app.swipeDown(velocity: .fast)
        XCTAssertTrue(deleteRow.waitForNonExistence(timeout: 5), "Menyen skal lukkes ved sveip ned")
        XCTAssertTrue(app.buttons["Hjem"].isHittable, "Fanelinjen skal være tilgjengelig igjen")
    }

    func testFilterPanelShowsAndClearsFilters() throws {
        let filterButton = app.buttons["Filter"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5), "Filterknappen skal vises")
        filterButton.tap()

        XCTAssertTrue(app.staticTexts["Språk"].waitForExistence(timeout: 5), "Filterpanelet skal vise Språk-seksjonen")
        let norwegianChip = app.buttons["Norsk"]
        XCTAssertTrue(norwegianChip.waitForExistence(timeout: 3), "Språkvalget Norsk skal vises")
        norwegianChip.tap()

        let resetButton = app.buttons["Nullstill"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3), "Nullstill skal vises når et filter er aktivt")
        resetButton.tap()
        XCTAssertTrue(resetButton.waitForNonExistence(timeout: 3), "Nullstill skal forsvinne når filtrene er fjernet")

        app.swipeDown(velocity: .fast)
    }

    func testSearchTabSwitcherTogglesPlaceholder() throws {
        let episodesTab = app.buttons["Episoder"]
        XCTAssertTrue(episodesTab.waitForExistence(timeout: 5), "Episoder-fanen skal vises")
        episodesTab.tap()
        XCTAssertTrue(
            app.textFields["Søk etter episoder"].waitForExistence(timeout: 3),
            "Søkefeltet skal bytte til episodesøk"
        )

        app.buttons["Podkaster"].tap()
        XCTAssertTrue(
            app.textFields["Søk etter podkaster"].waitForExistence(timeout: 3),
            "Søkefeltet skal bytte tilbake til podkastsøk"
        )
    }

    func testMyPodsRenders() throws {
        let myPodsTab = app.buttons["Mine podder"]
        XCTAssertTrue(myPodsTab.waitForExistence(timeout: 5), "Mine podder-fanen skal vises")
        myPodsTab.tap()

        // Simulator state is not reset between runs, so the view legitimately
        // shows either the empty state or subscribed podcasts.
        let emptyState = app.staticTexts["Ingen podkaster ennå"]
        let anyContent = app.scrollViews.firstMatch
        let found = emptyState.waitForExistence(timeout: 3) || anyContent.waitForExistence(timeout: 2)
        XCTAssertTrue(found, "Mine podder skal vise innhold eller tom tilstand")
    }
}

/// Flows that need real Podcast Index keys in `Config/Secrets.swift` and
/// network access. Excluded from CI, which runs `-only-testing:LyttejegerTests`
/// (see .github/workflows/test.yml). If UI tests are ever added to CI, include
/// only `LyttejegerUITests/LyttejegerUITests` — this class must stay local.
@MainActor
final class LyttejegerNetworkedUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "nb_NO", "-AppleLanguages", "(nb)"]
        app.launch()
    }

    override func tearDown() async throws {
        app = nil
    }

    private func searchAndOpenAbelsTaarn() throws {
        let searchField = app.textFields["Søk etter podkaster"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Søkefeltet skal vises")
        searchField.tap()
        searchField.typeText("abels tårn")

        // Same tree caveat as above: a subscription to Abels tårn puts a
        // matching label on the hidden Mine podder tab.
        let matches = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[cd] 'Abels tårn'"))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 15), "Søket skal finne Abels tårn")

        guard let result = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("Ingen synlig treff på Abels tårn")
            return
        }
        result.tap()
    }

    func testSearchOpensPodcastDetail() throws {
        try searchAndOpenAbelsTaarn()

        let detailTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[cd] 'Abels tårn'")
        ).firstMatch
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10), "Detaljvisningen skal vise podkasttittelen")
    }

    func testPlaybackShowsMiniPlayerAndStops() throws {
        try searchAndOpenAbelsTaarn()

        // Episode play buttons are labeled "Spill <episodetittel>".
        let matches = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Spill '"))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 15), "Episodelisten skal vise en spill-knapp")

        // ContentView keeps all three tabs alive in a ZStack, so the hidden
        // ones stay in the accessibility tree. With anything in the queue the
        // first match is Kø's off-screen "Spill alle episoder i køen", whose
        // hit point is {-1, -1}: the tap silently does nothing and the failure
        // surfaces much later, as a missing mini player. Take the first button
        // that is actually on screen.
        guard let playButton = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("Ingen synlig spill-knapp i episodelisten")
            return
        }
        playButton.tap()

        let stopButton = app.buttons["Stopp avspilling"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 10), "Minispilleren skal vises")
        stopButton.tap()
        XCTAssertTrue(stopButton.waitForNonExistence(timeout: 5), "Minispilleren skal forsvinne etter stopp")
    }
}
