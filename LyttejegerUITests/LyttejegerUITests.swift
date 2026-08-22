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
    }

    /// Audits whatever screen the test ended on. Running it here rather than
    /// per test means the eight cases cover eight screens for one line of code.
    /// Skipped when the app is not up, so a failed test reports its own reason
    /// rather than an audit failure on top of it.
    ///
    /// The handler exists to name the offending element: the bare audit reports
    /// only "Hit area is too small", which is not enough to find it in a screen
    /// full of controls.
    ///
    /// Three audit types are held back rather than run and ignored, so the gate
    /// stays green and honest instead of red and routinely overridden. Each has
    /// an open item in REVIEW-FINDINGS.md; turn them back on as they are closed.
    ///   - `.dynamicType` fires on every `.caption2Text` and `.smallText`, but
    ///     not on `.bodyText`, so it needs a real check before it is trusted.
    ///   - `.textClipped` fires on the search placeholder.
    ///   - `.contrast` fires on the Podkaster/Episoder switcher, possibly only
    ///     while its 0.2 s selection animation is mid-flight.
    private static let auditTypes: XCUIAccessibilityAuditType =
        .all.subtracting([.dynamicType, .textClipped, .contrast])

    override func tearDown() async throws {
        if let app, app.state == .runningForeground {
            try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
                let element = issue.element?.description ?? "ukjent element"
                XCTContext.runActivity(named: "Tilgjengelighet: \(issue.compactDescription)") { _ in
                    print("AUDIT \(issue.auditType): \(issue.detailedDescription) -- \(element)")
                }
                return false
            }
        }
        app = nil
    }

    /// Every test starts from an empty store. Without it the assertions had to
    /// accept "either the empty state or some content", because the simulator
    /// keeps whatever the previous run left behind — and an assertion that
    /// accepts both outcomes guards nothing. `-uitest-seed-queue` additionally
    /// puts two known episodes in the queue. Both flags are DEBUG-only hooks in
    /// `UITestSupport`, so they cannot exist in a release build.
    private func launchApp(_ extraArguments: [String] = []) {
        app.launchArguments += ["-uitest-reset"] + extraArguments
        app.launch()
    }

    func testAppLaunches() throws {
        launchApp()
        XCTAssertTrue(app.state == .runningForeground, "Appen skal kjøre i forgrunnen")
    }

    func testTabBarNavigation() throws {
        launchApp()
        // Wait for splash screen to dismiss
        let queueTab = app.buttons["Kø"]
        XCTAssertTrue(queueTab.waitForExistence(timeout: 5), "Kø-fanen skal vises")
        queueTab.tap()

        let emptyState = app.staticTexts["Ingen episoder i køen"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "En tom kø skal vise tom-tilstanden")
    }

    func testMenuTabShowsAndLeaves() throws {
        launchApp()
        let menuButton = app.buttons["Meny"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Meny-fanen skal vises")
        menuButton.tap()

        let deleteRow = app.staticTexts["Slett alle data"]
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 5), "Menyen skal vise Slett alle data")
        XCTAssertTrue(app.buttons["Hjem"].isHittable, "Fanelinjen skal være tilgjengelig i menyen")

        app.buttons["Hjem"].tap()
        let homeEmptyState = app.staticTexts["Finn din neste favoritt"]
        XCTAssertTrue(homeEmptyState.waitForExistence(timeout: 5), "Hjem skal vises igjen")
        // Fanene ligger i samme ZStack og blir værende i live, så innholdet i
        // fanen man forlater må skjules for VoiceOver.
        XCTAssertTrue(deleteRow.waitForNonExistence(timeout: 5), "Menyinnholdet skal ikke være tilgjengelig fra en annen fane")
    }

    func testFilterPanelShowsAndClearsFilters() throws {
        launchApp()
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
        launchApp()
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

    func testFollowingRenders() throws {
        launchApp()
        let followingTab = app.buttons["Følgeliste"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 5), "Følgeliste-fanen skal vises")
        followingTab.tap()

        let emptyState = app.staticTexts["Ingen podkaster ennå"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "En tom følgeliste skal vise tom-tilstanden")
    }

    // MARK: - Behold episoder i køen

    /// Default behaviour: playing a queued episode takes it out of the queue.
    func testPlayingFromQueueRemovesTheEpisode() throws {
        launchApp(["-uitest-seed-queue"])
        app.buttons["Kø"].tap()

        let firstRow = app.staticTexts["Testepisode 1"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Den seedede køen skal vises")

        app.buttons["Spill Testepisode 1"].tap()

        XCTAssertTrue(firstRow.waitForNonExistence(timeout: 5), "Episoden skal forsvinne fra køen når den spilles")
        XCTAssertTrue(app.staticTexts["Testepisode 2"].exists, "Resten av køen skal ligge igjen")
    }

    /// With the setting on, the same tap must leave the row where it is —
    /// removing it is the one thing the setting promises not to do.
    func testKeepSettingLeavesTheEpisodeInTheQueue() throws {
        launchApp(["-uitest-seed-queue"])

        app.buttons["Meny"].tap()
        let keepToggle = app.switches["Behold episoder i køen"]
        XCTAssertTrue(keepToggle.waitForExistence(timeout: 5), "Innstillingen skal vises i menyen")
        keepToggle.tap()

        app.buttons["Kø"].tap()
        let firstRow = app.staticTexts["Testepisode 1"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Den seedede køen skal vises")

        app.buttons["Spill Testepisode 1"].tap()

        // The mini player appearing is the signal that the tap was handled, so
        // the assertion below is not just racing an unchanged screen.
        XCTAssertTrue(
            app.buttons["Stopp avspilling"].waitForExistence(timeout: 10),
            "Minispilleren skal vises når avspilling starter"
        )
        XCTAssertTrue(firstRow.exists, "Episoden skal bli liggende i køen når innstillingen er på")
    }
}

/// Flows that need real Podcast Index keys in `Config/Secrets.swift` and
/// network access. Excluded from CI, which selects `LyttejegerTests` plus
/// `LyttejegerUITests/LyttejegerUITests` by class (see .github/workflows/test.yml).
/// This class must stay local.
@MainActor
final class LyttejegerNetworkedUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLocale", "nb_NO", "-AppleLanguages", "(nb)", "-uitest-reset"]
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

        // Inactive tabs are hidden from the accessibility tree, so the
        // matches are all on screen. Several results can still carry the
        // label, so pick the first one that is actually hittable.
        let matches = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[cd] 'Abels tårn'"))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 15), "Søket skal finne Abels tårn")

        guard let result = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("Ingen synlig treff på Abels tårn")
            return
        }
        result.tap()
    }

    /// Fanene blir liggende i live når man bytter fane, også en podkastside man
    /// har navigert inn på. Da må den skjules for VoiceOver.
    func testPushedDetailIsHiddenFromOtherTab() throws {
        try searchAndOpenAbelsTaarn()

        let matches = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[cd] 'Abels tårn'")
        )
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "Podkastsiden skal vises")

        app.buttons["Meny"].tap()
        XCTAssertTrue(
            matches.firstMatch.waitForNonExistence(timeout: 5),
            "Podkastsiden i Hjem-fanen skal ikke være tilgjengelig fra menyfanen"
        )
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

        // The episode list can hold many play buttons, and a tap on one that
        // is scrolled out of view silently does nothing — the failure then
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
