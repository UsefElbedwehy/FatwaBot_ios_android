import XCTest
import PrayerKit
@testable import PrayerFeature

final class PrayerViewModelTests: XCTestCase {
    struct StubLocation: LocationProviding {
        let cachedLocation: UserLocation?
        let resolveResult: LocationState

        func cached() -> UserLocation? { cachedLocation }
        func resolve() async -> LocationState { resolveResult }
    }

    final class SpyLiveActivity: PrayerLiveActivityManaging, @unchecked Sendable {
        private(set) var startCount = 0
        private(set) var updateCount = 0
        private(set) var endCount = 0
        private(set) var lastPrayerName: PrayerName?
        private(set) var lastPrayerTime: Date?

        func start(locationName: String, prayerName: PrayerName, prayerTime: Date) async {
            startCount += 1
            lastPrayerName = prayerName
            lastPrayerTime = prayerTime
        }

        func update(prayerName: PrayerName, prayerTime: Date) async {
            updateCount += 1
            lastPrayerName = prayerName
            lastPrayerTime = prayerTime
        }

        func end() async {
            endCount += 1
        }
    }

    final class InMemoryLiveActivityPreferenceStore: LiveActivityPreferenceStoring, @unchecked Sendable {
        private var enabled: Bool
        init(enabled: Bool = false) { self.enabled = enabled }
        func isEnabled() -> Bool { enabled }
        func setEnabled(_ enabled: Bool) { self.enabled = enabled }
    }

    private let riyadh = UserLocation(
        latitude: 24.7136, longitude: 46.6753, name: "الرياض", countryCode: "SA", isManual: false
    )
    private let fixedNow = Date(timeIntervalSince1970: 1_774_000_000)

    /// `syncLiveActivity()` fires a detached `Task` fire-and-forget; a single
    /// `Task.yield()` doesn't reliably let it complete before assertions run,
    /// so poll briefly instead of relying on cooperative-scheduling luck.
    private func waitUntil(
        timeout: TimeInterval = 1.0,
        _ condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    @MainActor
    func testCachedLocationPaintsImmediately() {
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .denied),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        XCTAssertEqual(viewModel.status, .ready)
        XCTAssertNotNil(viewModel.today)
        XCTAssertNotNil(viewModel.nextPrayer)
        XCTAssertNotNil(viewModel.hijri)
    }

    @MainActor
    func testDeniedWithoutCacheNeedsLocation() async {
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: nil, resolveResult: .denied),
            now: { [fixedNow] in fixedNow }
        )
        await viewModel.start()
        XCTAssertEqual(viewModel.status, .needsLocation)
        XCTAssertNil(viewModel.today)
    }

    @MainActor
    func testManualCitySelectionComputesTimes() {
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: nil, resolveResult: .denied),
            settings: PrayerSettings(method: "egyptian"),
            now: { [fixedNow] in fixedNow }
        )
        let cairo = ManualCity.bundled.first { $0.id == "cairo" }!
        viewModel.select(city: cairo, displayName: "القاهرة")
        XCTAssertEqual(viewModel.status, .ready)
        XCTAssertEqual(viewModel.location?.isManual, true)
        XCTAssertNotNil(viewModel.nextPrayer)
    }

    @MainActor
    func testSettingsUpdateRecomputes() {
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        let before = viewModel.today?.time(.fajr)
        viewModel.update(settings: PrayerSettings(method: "umm_al_qura", adjustments: [.fajr: 10]))
        let after = viewModel.today?.time(.fajr)
        XCTAssertEqual(after?.timeIntervalSince(before ?? .distantPast), 600)
    }

    final class ReloadCounter: @unchecked Sendable {
        var count = 0
    }

    @MainActor
    func testCachedLocationOnInitSkipsWidgetWriteButStartDoesNotSkipIt() async {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let widgetStore = WidgetSnapshotStore(appGroupContainer: tmpDir)

        let counter = ReloadCounter()
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            widgetStore: widgetStore,
            reloadWidgets: { counter.count += 1 },
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        XCTAssertEqual(counter.count, 0, "cached-location path in init must not do the widget disk write + reload IPC call")
        XCTAssertNil(widgetStore.read(), "no widget snapshot file should exist yet")

        await viewModel.start()
        XCTAssertEqual(counter.count, 1, "start() resolving location must still write the widget snapshot")
        XCTAssertNotNil(widgetStore.read())
    }

    @MainActor
    func testDisabledPreferenceNeverStartsTheActivity() async {
        let spy = SpyLiveActivity()
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            liveActivity: spy,
            liveActivityPreference: InMemoryLiveActivityPreferenceStore(enabled: false),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        await viewModel.start()
        try? await Task.sleep(nanoseconds: 50_000_000) // grace period to prove absence, not presence
        XCTAssertEqual(spy.startCount, 0, "must respect an explicitly-disabled preference")
    }

    @MainActor
    func testUserDefaultsStoreDefaultsToEnabled() {
        let suiteName = "PrayerViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsLiveActivityPreferenceStore(defaults: defaults)
        XCTAssertTrue(store.isEnabled(), "on by default per stakeholder direction (2026-07-11), overriding ADR-0016")
        store.setEnabled(false)
        XCTAssertFalse(store.isEnabled(), "an explicit opt-out must still be respected")
    }

    @MainActor
    func testEnablingLiveActivityStartsItWithCurrentNextPrayer() async {
        let spy = SpyLiveActivity()
        let preference = InMemoryLiveActivityPreferenceStore(enabled: false)
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            liveActivity: spy,
            liveActivityPreference: preference,
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        await viewModel.start()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(spy.startCount, 0)

        viewModel.setLiveActivityEnabled(true)
        await waitUntil { spy.startCount >= 1 }
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(spy.lastPrayerName, viewModel.nextPrayer?.next)
        XCTAssertEqual(spy.lastPrayerTime, viewModel.nextPrayer?.nextTime)
        XCTAssertTrue(preference.isEnabled())
    }

    @MainActor
    func testDisablingLiveActivityEndsItImmediately() async {
        let spy = SpyLiveActivity()
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            liveActivity: spy,
            liveActivityPreference: InMemoryLiveActivityPreferenceStore(enabled: true),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        await viewModel.start()
        await waitUntil { spy.startCount > 0 }
        XCTAssertGreaterThan(spy.startCount, 0)

        viewModel.setLiveActivityEnabled(false)
        await waitUntil { spy.endCount >= 1 }
        XCTAssertEqual(spy.endCount, 1)
    }

    @MainActor
    func testRefreshNextPrayerSyncsLiveActivityWhenEnabled() async {
        let spy = SpyLiveActivity()
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            liveActivity: spy,
            liveActivityPreference: InMemoryLiveActivityPreferenceStore(enabled: true),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        await viewModel.start()
        await waitUntil { spy.startCount > 0 }
        let callsAfterStart = spy.startCount

        viewModel.refreshNextPrayer()
        await waitUntil { spy.startCount > callsAfterStart }
        XCTAssertGreaterThan(spy.startCount, callsAfterStart, "a timer-tick refresh must also sync the activity while enabled")
    }

    /// Regression test for a real bug, live-reproduced: prayer times were
    /// computed correctly in absolute terms but *displayed* via the device's
    /// timezone rather than the resolved location's — a Riyadh location on a
    /// device set to Pacific time showed Fajr shifted ~11 hours into the
    /// afternoon. `displayTimeZone` must reflect the location, not the
    /// injected device calendar.
    @MainActor
    func testDisplayTimeZoneUsesResolvedLocationNotDeviceCalendar() {
        var deviceCalendar = Calendar(identifier: .gregorian)
        deviceCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let riyadhWithZone = UserLocation(
            latitude: 24.7136, longitude: 46.6753, name: "الرياض", countryCode: "SA", isManual: false,
            timeZone: TimeZone(identifier: "Asia/Riyadh")
        )
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadhWithZone, resolveResult: .resolved(riyadhWithZone)),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow },
            calendar: deviceCalendar
        )
        XCTAssertEqual(viewModel.displayTimeZone.identifier, "Asia/Riyadh")
    }

    /// Companion regression test for the same bug, at a day boundary: which
    /// *civil day* "today" resolves to must also follow the location, not
    /// the device. Picks an instant where Riyadh (UTC+3) has already crossed
    /// into January 1st while Los Angeles (PST, UTC-8) is still on the 31st.
    @MainActor
    func testCivilDayFollowsLocationTimeZoneNotDeviceAcrossMidnight() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let crossoverNow = utc.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 1, minute: 0))!

        var deviceCalendar = Calendar(identifier: .gregorian)
        deviceCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let riyadhWithZone = UserLocation(
            latitude: 24.7136, longitude: 46.6753, name: "الرياض", countryCode: "SA", isManual: false,
            timeZone: TimeZone(identifier: "Asia/Riyadh")
        )
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadhWithZone, resolveResult: .resolved(riyadhWithZone)),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { crossoverNow },
            calendar: deviceCalendar
        )
        XCTAssertEqual(viewModel.today?.date.year, 2026)
        XCTAssertEqual(viewModel.today?.date.month, 1)
        XCTAssertEqual(viewModel.today?.date.day, 1, "Riyadh's civil day, not Dec 31 from the device's Pacific calendar")
    }

    /// Regression test for a second bug found while live-verifying the
    /// timezone fix above: `ar_SA` and similar locales default
    /// `Calendar.current`'s *identifier* to Islamic Umm al-Qura, not just its
    /// timezone — a real device configuration, reproduced live on the
    /// simulator used to test this app. Adhan has no concept of calendar
    /// systems; it treats whatever year/month/day it's given as Gregorian.
    /// Extracting "today" via an injected Islamic calendar and handing e.g.
    /// (1448, 3, 20) to Adhan silently computed real prayer times for
    /// Gregorian March 20th, year 1448 AD — centuries off, caught only by
    /// checking the raw widget snapshot JSON, not by anything on screen.
    @MainActor
    func testGregorianDayIsUsedEvenWhenDeviceCalendarIsIslamic() {
        var islamicDeviceCalendar = Calendar(identifier: .islamicUmmAlQura)
        islamicDeviceCalendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow },
            calendar: islamicDeviceCalendar
        )
        // fixedNow is 2026-03-20T09:46:40Z — must resolve to that real
        // Gregorian day, not the Hijri year/month/day misread as Gregorian.
        XCTAssertEqual(viewModel.today?.date.year, 2026)
        XCTAssertEqual(viewModel.today?.date.month, 3)
        XCTAssertEqual(viewModel.today?.date.day, 20)
    }

    @MainActor
    func testDayOffsetNavigation() {
        let viewModel = PrayerViewModel(
            locationProvider: StubLocation(cachedLocation: riyadh, resolveResult: .resolved(riyadh)),
            settings: PrayerSettings(method: "umm_al_qura"),
            now: { [fixedNow] in fixedNow }
        )
        let today = viewModel.day(offset: 0)
        let nextWeek = viewModel.day(offset: 7)
        XCTAssertNotNil(today)
        XCTAssertNotNil(nextWeek)
        let gap = nextWeek!.time(.fajr).timeIntervalSince(today!.time(.fajr))
        XCTAssert(abs(gap - 7 * 86_400) < 1_800, "fajr a week out should be ~7 days away")
    }
}
