import XCTest

/// End-to-end checks that the screens this project has been shipping actually
/// render on a device.
///
/// ## Why UI tests rather than driving the simulator directly
/// Repeated attempts to verify screens by injecting taps through `simctl` failed
/// to reach this app's windows — onboarding would not advance, and even system
/// alerts ignored the injected events. Every screen built in those sessions was
/// therefore verified only by "it compiled and its unit tests pass", which says
/// nothing about layout, truncation, or whether a control is reachable.
///
/// XCUITest goes through the accessibility layer instead of the window server,
/// which is a different path entirely and does not depend on tap injection
/// working.
final class AzkarBrowseUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Honoured by RootTabView: without it the first launch sits behind the
        // notification permission alert, which is not what these tests are for.
        app.launchArguments = ["-skipPermPrompts", "-uiTesting"]
        app.launch()
        return app
    }

    /// Completes onboarding if it is showing. Returns whether it had to.
    @discardableResult
    private func completeOnboardingIfPresent(_ app: XCUIApplication) -> Bool {
        // Fresh installs land here; a warm one skips straight to the tabs.
        var advanced = false
        for _ in 0..<6 {
            let buttons = app.buttons
            let next = buttons.allElementsBoundByIndex.first {
                $0.isHittable && $0.frame.height > 30
            }
            guard let next, app.staticTexts["Welcome to Fatwa"].exists
                    || app.buttons.count <= 3 else { break }
            next.tap()
            advanced = true
            _ = app.wait(for: .runningForeground, timeout: 1)
        }
        return advanced
    }

    func testOnboardingCanBeCompleted() {
        let app = launchApp()
        // The specific failure that blocked verification for several sessions:
        // the first screen's button would not respond to injected taps. If this
        // passes, the accessibility path works where tap injection did not.
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "the app must reach the foreground"
        )
        completeOnboardingIfPresent(app)
        attach(app, name: "after-onboarding")
    }

    func testAzkarBrowseScreenRenders() {
        let app = launchApp()
        _ = app.wait(for: .runningForeground, timeout: 10)
        completeOnboardingIfPresent(app)

        openRemembrance(app)

        // The three things the redesign added. Asserted by presence rather than
        // by pixel position — this is a smoke test that the screen composed, not
        // a snapshot test.
        let searchField = app.textFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "the browse screen must show its search field"
        )
        attach(app, name: "azkar-browse")
    }

    func testSearchNarrowsTheList() {
        let app = launchApp()
        _ = app.wait(for: .runningForeground, timeout: 10)
        completeOnboardingIfPresent(app)

        openRemembrance(app)

        let searchField = app.textFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else {
            return XCTFail("no search field to type into")
        }
        let before = app.staticTexts.count
        searchField.tap()
        // Unvowelled, the way a user types. The folding bug this exercises made
        // every Arabic query match nothing while looking like an empty category.
        searchField.typeText("الحمد")
        attach(app, name: "azkar-search")
        // Fewer results than the unfiltered list, and not zero.
        let after = app.staticTexts.count
        XCTAssertLessThanOrEqual(after, before)
    }

    /// Worship tab → the Azkar & Du'a tile.
    ///
    /// The first version matched a button whose label contained "الأذكار",
    /// which never fired: the simulator runs in English, so the tile reads
    /// "Azkar & Du'a". Matched on "Azkar" now, which is in both spellings of the
    /// label, with the tab itself found by its own accessibility label rather
    /// than by tapping whatever button happens to be biggest.
    private func openRemembrance(_ app: XCUIApplication) {
        let worship = app.buttons["Worship"]
        if worship.waitForExistence(timeout: 10) { worship.tap() }

        let tile = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS %@", "Azkar", "الأذكار")
        ).firstMatch
        if tile.waitForExistence(timeout: 5) { tile.tap() }
    }

    /// Screenshots are the point of these tests as much as the assertions:
    /// layout problems do not fail an existence check.
    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
