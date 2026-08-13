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
        nameResolver: @escaping FixedWirdSlots.NameResolver = FixedWirdSlots.defaultNames,
        now: Date? = nil
    ) -> AwradViewModel {
        let time = now ?? fixedNow
        return AwradViewModel(
            store: store, haptics: haptics, activityEvents: activityEvents,
            nameResolver: nameResolver, now: { time }, calendar: utcCalendar
        )
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

    // MARK: - Leaderboard currency
    //
    // Only the four fixed slots are ranked (owner decision, 2026-07). These two
    // tests are the contract: if `fixed_wird_completed` ever stops firing, the
    // leaderboard silently flatlines with no other symptom.

    @MainActor
    func testCrossingTargetOnAFixedSlotEmitsTheLeaderboardEvent() {
        let events = SpyActivityEvents()
        let viewModel = makeViewModel(activityEvents: events)
        viewModel.addTodaysWird()

        let quran = viewModel.wirds.first { $0.id == FixedWirdSlot.dailyQuran.wirdId }!
        XCTAssertEqual(quran.target, 1)

        viewModel.tick(wirdId: quran.id)
        XCTAssertEqual(events.recorded.map(\.eventType), ["wird_ticked", "fixed_wird_completed"])
        XCTAssertEqual(events.recorded.last?.metadata["wird_id"], quran.id)

        // Ticking past target must not score again — otherwise the cap is the
        // only thing standing between this and "who tapped the most".
        viewModel.tick(wirdId: quran.id)
        XCTAssertEqual(events.recorded.filter { $0.eventType == "fixed_wird_completed" }.count, 1)
    }

    @MainActor
    func testCustomWirdsAreDeliberatelyNotRanked() {
        let events = SpyActivityEvents()
        let viewModel = makeViewModel(activityEvents: events)
        viewModel.createWird(fromTemplate: template(target: 1))
        viewModel.tick(wirdId: viewModel.wirds[0].id)

        XCTAssertEqual(events.recorded.map(\.eventType), ["wird_ticked"])
        XCTAssertFalse(events.recorded.contains { $0.eventType == "fixed_wird_completed" })
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
    func testDeletingRemovesFromActiveBoardButKeepsHistoricalProgress() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(target: 5))
        let wirdId = viewModel.wirds[0].id
        viewModel.tick(wirdId: wirdId, amount: 5)
        XCTAssertEqual(viewModel.stats.salawatCount, 5)

        viewModel.deleteWird(wirdId)
        XCTAssertTrue(viewModel.activeWirds.isEmpty, "deleted wird must not appear on the active board")
        XCTAssertEqual(viewModel.stats.salawatCount, 5, "historical progress must remain in stats")
    }

    @MainActor
    func testDayCompletionExcludesDeletedWirds() {
        let viewModel = makeViewModel()
        viewModel.createWird(fromTemplate: template(name: "A", target: 1))
        viewModel.createWird(fromTemplate: template(name: "B", target: 1))
        let (a, b) = (viewModel.wirds[0].id, viewModel.wirds[1].id)
        viewModel.deleteWird(b) // deleted before ever being touched

        viewModel.tick(wirdId: a, amount: 1)
        XCTAssertTrue(viewModel.markDayComplete(), "deleted wird B must not block completion")
    }

    // MARK: - Fixed-slot seeding and deletion (client decision, 2026-08-12)
    //
    // Nothing is seeded by default anymore; a user opts in with "أضف ورد
    // اليوم", and once on the board the four fixed slots are ordinary wirds —
    // including being deletable, which the old model explicitly refused.

    @MainActor
    func testFreshBoardHasNoWirdsUntilAddTodaysWirdIsCalled() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.wirds.isEmpty)

        viewModel.addTodaysWird()
        XCTAssertEqual(viewModel.wirds.count, FixedWirdSlot.allCases.count)
        XCTAssertTrue(viewModel.wirds.allSatisfy(\.isFixed))
    }

    @MainActor
    func testAddTodaysWirdPersistsThroughTheStore() {
        let store = InMemoryStore()
        let viewModel = makeViewModel(store: store)
        viewModel.addTodaysWird()

        XCTAssertEqual(store.wirds.count, FixedWirdSlot.allCases.count)
    }

    @MainActor
    func testAddTodaysWirdDoesNotDisturbExistingCustomWirds() {
        let viewModel = makeViewModel()
        viewModel.createCustomWird(name: "ورد خاص", type: "custom", target: 3, unit: "times", frequency: "daily")
        let customId = viewModel.wirds[0].id

        viewModel.addTodaysWird()
        XCTAssertTrue(viewModel.wirds.contains { $0.id == customId })
        XCTAssertEqual(viewModel.wirds.count, FixedWirdSlot.allCases.count + 1)
    }

    @MainActor
    func testFixedSlotsCanBeDeletedUnlikeTheOldModel() {
        let viewModel = makeViewModel()
        viewModel.addTodaysWird()
        let qiyamId = FixedWirdSlot.qiyamAlLayl.wirdId

        XCTAssertTrue(viewModel.deleteWird(qiyamId))
        XCTAssertFalse(viewModel.activeWirds.contains { $0.id == qiyamId })
    }

    @MainActor
    func testAddTodaysWirdReAddsOnlyTheMissingSlots() {
        let viewModel = makeViewModel()
        viewModel.addTodaysWird()
        viewModel.deleteWird(FixedWirdSlot.qiyamAlLayl.wirdId)
        XCTAssertEqual(viewModel.activeWirds.count, FixedWirdSlot.allCases.count - 1)

        viewModel.addTodaysWird()
        XCTAssertEqual(viewModel.activeWirds.count, FixedWirdSlot.allCases.count)
    }

    /// Client report: a fixed slot seeded under one language stayed in that
    /// language forever after switching the device's language — because
    /// nothing re-seeds automatically anymore, and the old name was frozen at
    /// creation. Loading the board (init or `reload()`) must self-heal this
    /// without the user doing anything.
    @MainActor
    func testLoadingTheBoardRefreshesAStaleFixedSlotNameToTheCurrentLanguage() {
        let store = InMemoryStore()
        store.wirds = [FixedWirdSlots.wird(for: .qiyamAlLayl, name: { _ in "Night Prayer (Qiyam)" }, now: fixedNow)]

        let viewModel = makeViewModel(store: store, nameResolver: { _ in "قيام الليل" })

        XCTAssertEqual(viewModel.wirds.first?.name, "قيام الليل")
        XCTAssertEqual(store.wirds.first?.name, "قيام الليل", "the refreshed name must be persisted, not just shown in memory")
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
