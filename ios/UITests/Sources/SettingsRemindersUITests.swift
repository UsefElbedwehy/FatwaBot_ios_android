import XCTest

/// The reminder settings this session added, verified on a running app rather
/// than by "it compiled".
final class SettingsRemindersUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchToSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipPermPrompts", "-uiTesting"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        // Onboarding, when a fresh install shows it.
        for _ in 0..<4 {
            guard let next = app.buttons.allElementsBoundByIndex.first(where: {
                $0.isHittable && $0.frame.height > 30
            }), !app.buttons["Settings"].exists else { break }
            next.tap()
        }
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "no Settings tab")
        settings.tap()
        return app
    }

    /// Scrolls until `element` is on screen, or gives up.
    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists
    }

    func testEachFixedWirdHasItsOwnReminderRow() {
        let app = launchToSettings()
        // The four slots the client named, each now its own row rather than one
        // shared time. Labels are the app's own, so this fails if a slot stops
        // being rendered — the exact regression a unit test cannot see.
        for name in ["Night Prayer (Qiyam)", "Daily Qur'an Wird", "Morning Adhkar", "Evening Adhkar"] {
            let row = app.staticTexts[name]
            XCTAssertTrue(scrollTo(app, row), "missing reminder row for \(name)")
        }
        XCTAssertTrue(
            scrollTo(app, app.staticTexts["Your other wirds"]),
            "user-created wirds must still have their shared time"
        )
        attach(app, name: "settings-wird-times")
    }

    func testTheAzkarSlotsOfferFollowingThePrayer() {
        let app = launchToSettings()
        // "Follow Fajr time" / "Follow Asr time" — the option the client asked
        // for. Matched on the prefix so the prayer name can be localised without
        // prayer phrase sits after it.
        let follow = app.switches.matching(
            NSPredicate(format: "label CONTAINS %@", "Follow")
        )
        // Scroll the wird section into view first; SwiftUI does not materialise
        // rows far off screen.
        scrollTo(app, app.staticTexts["Morning Adhkar"])
        XCTAssertGreaterThanOrEqual(
            follow.count, 2,
            "أذكار الصباح and أذكار المساء must each offer prayer anchoring"
        )
        attach(app, name: "settings-follow-prayer")
    }

    func testTurningOnFollowFajrReplacesTheClockPicker() {
        let app = launchToSettings()
        scrollTo(app, app.staticTexts["Morning Adhkar"])
        let follow = app.switches.matching(
            NSPredicate(format: "label CONTAINS %@", "Follow")
        ).firstMatch
        guard follow.waitForExistence(timeout: 5) else {
            return XCTFail("no follow-prayer switch to toggle")
        }
        // Assert the *transition*, not an absolute count: settings persist
        // between runs, so a previous test may have left this switch either way.
        let wasOn = follow.value as? String == "1"
        let pickersBefore = app.datePickers.count
        follow.tap()
        let pickersAfter = app.datePickers.count
        if wasOn {
            XCTAssertGreaterThan(
                pickersAfter, pickersBefore,
                "clearing the anchor must return the slot's time picker"
            )
        } else {
            XCTAssertLessThan(
                pickersAfter, pickersBefore,
                "anchoring must remove the slot's now-meaningless time picker"
            )
        }
        // Either way the slot must still be identifiable.
        XCTAssertTrue(
            app.staticTexts["Morning Adhkar"].exists,
            "an anchored slot must still say which wird it is"
        )
        attach(app, name: "settings-anchored")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
