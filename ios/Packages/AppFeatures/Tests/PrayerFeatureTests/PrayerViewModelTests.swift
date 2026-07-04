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

    private let riyadh = UserLocation(
        latitude: 24.7136, longitude: 46.6753, name: "الرياض", countryCode: "SA", isManual: false
    )
    private let fixedNow = Date(timeIntervalSince1970: 1_774_000_000)

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
