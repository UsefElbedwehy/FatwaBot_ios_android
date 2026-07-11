import XCTest
import ContentKit
import CoreKit
@testable import AwradFeature

final class AwradViewModelTests: XCTestCase {
    final class InMemoryStore: WirdStoring, @unchecked Sendable {
        var wirds: [Wird] = []
        var progress: [WirdDailyProgress] = []
        var completions: [WirdDayCompletionRecord] = []
        func loadWirds() -> [Wird] { wirds }
        func saveWirds(_ wirds: [Wird]) { self.wirds = wirds }
        func loadProgress() -> [WirdDailyProgress] { progress }
        func saveProgress(_ progress: [WirdDailyProgress]) { self.progress = progress }
        func loadDayCompletions() -> [WirdDayCompletionRecord] { completions }
        func recordDayCompletion(_ record: WirdDayCompletionRecord) { completions.append(record) }
    }

    final class SpyActivityEvents: ActivityEventRecording, @unchecked Sendable {
        var recorded: [(eventType: String, metadata: [String: String])] = []
        func record(eventType: String, metadata: [String: String]) { recorded.append((eventType, metadata)) }
    }

    final class SpyHaptics: HapticsProviding, @unchecked Sendable {
        var tickCount = 0
        var targetReachedCount = 0
        func tick() { tickCount += 1 }
        func targetReached() { targetReachedCount += 1 }
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_774_000_000) // a fixed UTC instant
    private let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    @MainActor
    private func makeViewModel(
        store: WirdStoring = InMemoryStore(),
        haptics: HapticsProviding = NoopHaptics(),
        activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
        now: Date? = nil
    ) -> AwradViewModel {
        let time = now ?? fixedNow
        return AwradViewModel(store: store, haptics: haptics, activityEvents: activityEvents, now: { time }, calendar: utcCalendar)
    }

    private func template(name: String = "الصلاة على النبي", type: String = "salawat", target: Int = 100, unit: String = "times") -> WirdTemplate {
        WirdTemplate(id: "t1", name: name, description: "", type: type, defaultTarget: target, defaultUnit: unit, defaultFrequency: "daily")
    }

    @MainActor
    func testTickingPastTargetDoesNotError() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(target: 3))
        let wirdId = viewModel.wirds[0].id
        for _ in 0..<10 { viewModel.tick(wirdId: wirdId) }
        XCTAssertEqual(viewModel.todayCount(for: wirdId), 10)
    }

    @MainActor
    func testDayCompletionRequiresAllActiveWirdsToReachTarget() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(name: "A", target: 2))
        viewModel.createWird(fromTemplate: template(name: "B", target: 2))
        let (a, b) = (viewModel.wirds[0].id, viewModel.wirds[1].id)

        viewModel.tick(wirdId: a, amount: 2)
        XCTAssertFalse(viewModel.markDayComplete(), "only one of two wirds met target")
        XCTAssertFalse(viewModel.isDayCompletedToday)

        viewModel.tick(wirdId: b, amount: 2)
        XCTAssertTrue(viewModel.markDayComplete())
        XCTAssertTrue(viewModel.isDayCompletedToday)
    }

    @MainActor
    func testMarkDayCompleteIsIdempotent() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(target: 1))
        viewModel.tick(wirdId: viewModel.wirds[0].id)
        XCTAssertTrue(viewModel.markDayComplete())
        XCTAssertFalse(viewModel.markDayComplete(), "already completed today — no duplicate record")
        XCTAssertEqual(viewModel.dayCompletions.count, 1)
    }

    @MainActor
    func testTickFiresARegularHapticThenTargetReachedOnceOnCrossingTheTarget() {
        let haptics = SpyHaptics()
        let viewModel = makeViewModel(haptics: haptics)
        viewModel.createWird(fromTemplate: template(target: 3))
        let wirdId = viewModel.wirds[0].id

        viewModel.tick(wirdId: wirdId)
        viewModel.tick(wirdId: wirdId)
        XCTAssertEqual(haptics.tickCount, 2)
        XCTAssertEqual(haptics.targetReachedCount, 0)

        viewModel.tick(wirdId: wirdId) // crosses target (3)
        XCTAssertEqual(haptics.targetReachedCount, 1, "must fire exactly once at the crossing")

        viewModel.tick(wirdId: wirdId) // past target — a regular tick, not another target-reached
        XCTAssertEqual(haptics.targetReachedCount, 1)
    }

    @MainActor
    func testMarkDayCompleteFiresTargetReachedHapticOnlyWhenItActuallyCompletes() {
        let haptics = SpyHaptics()
        let viewModel = makeViewModel(haptics: haptics)
        viewModel.createWird(fromTemplate: template(target: 1))
        viewModel.tick(wirdId: viewModel.wirds[0].id)
        haptics.targetReachedCount = 0 // reset after the tick's own crossing haptic

        XCTAssertTrue(viewModel.markDayComplete())
        XCTAssertEqual(haptics.targetReachedCount, 1)

        XCTAssertFalse(viewModel.markDayComplete(), "already completed today")
        XCTAssertEqual(haptics.targetReachedCount, 1, "must not fire again on the no-op re-call")
    }

    @MainActor
    func testTickRecordsAWirdTickedActivityEvent() {
        let events = SpyActivityEvents()
        let viewModel = makeViewModel(activityEvents: events)
        viewModel.createWird(fromTemplate: template(target: 3))
        viewModel.tick(wirdId: viewModel.wirds[0].id)
        XCTAssertEqual(events.recorded.map(\.eventType), ["wird_ticked"])
    }

    @MainActor
    func testMarkDayCompleteRecordsAnActivityEventOnlyWhenItActuallyCompletes() {
        let events = SpyActivityEvents()
        let viewModel = makeViewModel(activityEvents: events)
        viewModel.createWird(fromTemplate: template(target: 1))
        viewModel.tick(wirdId: viewModel.wirds[0].id)

        XCTAssertTrue(viewModel.markDayComplete())
        XCTAssertFalse(viewModel.markDayComplete()) // idempotent no-op

        XCTAssertEqual(events.recorded.map(\.eventType), ["wird_ticked", "wird_day_completed"])
    }

    @MainActor
    func testArchivingRemovesFromActiveBoardButKeepsHistoricalProgress() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(target: 5))
        let wirdId = viewModel.wirds[0].id
        viewModel.tick(wirdId: wirdId, amount: 5)
        XCTAssertEqual(viewModel.stats.salawatCount, 5)

        viewModel.archiveWird(wirdId)
        XCTAssertTrue(viewModel.activeWirds.isEmpty, "archived wird must not appear on the active board")
        XCTAssertEqual(viewModel.stats.salawatCount, 5, "historical progress must remain in stats")
    }

    @MainActor
    func testDayCompletionExcludesArchivedWirds() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(name: "A", target: 1))
        viewModel.createWird(fromTemplate: template(name: "B", target: 1))
        let (a, b) = (viewModel.wirds[0].id, viewModel.wirds[1].id)
        viewModel.archiveWird(b) // archived before ever being touched

        viewModel.tick(wirdId: a, amount: 1)
        XCTAssertTrue(viewModel.markDayComplete(), "archived wird B must not block completion")
    }

    @MainActor
    func testStatsAggregationAcrossTypeAndUnitCombinations() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(name: "Salawat", type: "salawat", target: 100, unit: "times"))
        viewModel.createWird(fromTemplate: template(name: "Quran", type: "quran_reading", target: 5, unit: "pages"))
        viewModel.createWird(fromTemplate: template(name: "Istighfar", type: "istighfar", target: 100, unit: "times"))
        let (salawat, quran, istighfar) = (viewModel.wirds[0].id, viewModel.wirds[1].id, viewModel.wirds[2].id)

        viewModel.tick(wirdId: salawat, amount: 30)
        viewModel.tick(wirdId: quran, amount: 3)
        viewModel.tick(wirdId: istighfar, amount: 20)

        let stats = viewModel.stats
        XCTAssertEqual(stats.quranPagesCount, 3, "only page-unit wirds count toward Qur'an pages")
        XCTAssertEqual(stats.salawatCount, 30, "only salawat-type wirds count toward salawat")
        XCTAssertEqual(stats.totalDhikrCount, 50, "non-page wirds (salawat + istighfar) sum into the general dhikr total")
    }

    @MainActor
    func testTemplateListRendersOfflineFromBundledSeed() async {
        // No live ContentService injected — mirrors "renders even fully offline
        // on first launch" via the bundled seed fallback ContentKit provides.
        let viewModel = makeViewModel()
        await viewModel.loadTemplates(locale: "ar")
        XCTAssertTrue(viewModel.templates.isEmpty, "without a ContentService, templates stay empty rather than crashing")
    }

    @MainActor
    func testCustomWirdCreation() {
        let viewModel = makeViewModel()
        viewModel.createCustomWird(name: "ورد خاص", type: "custom", target: 0, unit: "times", frequency: "daily")
        XCTAssertEqual(viewModel.wirds.first?.target, 1, "target is clamped to at least 1")
    }
}
