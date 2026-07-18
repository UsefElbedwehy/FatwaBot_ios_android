import XCTest
import ContentKit
import CoreKit
@testable import DuaFeature

final class DuaViewModelTests: XCTestCase {
    final class InMemoryStore: DuaStoring, @unchecked Sendable {
        var favorites: [FavoriteDua] = []
        func loadFavorites() -> [FavoriteDua] { favorites }
        func saveFavorites(_ favorites: [FavoriteDua]) { self.favorites = favorites }
    }

    final class SpySearchHistoryRecording: SearchHistoryRecording, @unchecked Sendable {
        private(set) var recorded: [(source: String, queryText: String, locale: String)] = []
        func record(source: String, queryText: String, locale: String) {
            recorded.append((source, queryText, locale))
        }
    }

    final class SpyHaptics: HapticsProviding, @unchecked Sendable {
        var tickCount = 0
        var targetReachedCount = 0
        func tick() { tickCount += 1 }
        func targetReached() { targetReachedCount += 1 }
    }

    private func dua(_ id: String, title: String, arabicText: String, translation: String?) -> Dua {
        Dua(id: id, sortOrder: 0, title: title, arabicText: arabicText, transliteration: nil, translation: translation, source: "src")
    }

    private func category(_ id: String, duas: [Dua]) -> DuaCategory {
        DuaCategory(id: id, slug: id, name: id, sortOrder: 0, duas: duas)
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_774_000_000)

    private var istikhara: Dua {
        dua("istikhara", title: "دعاء الاستخارة", arabicText: "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ", translation: "seeking guidance")
    }

    private var distress: Dua {
        dua("distress", title: "دعاء الكرب", arabicText: "لا إله إلا الله", translation: "at times of distress")
    }

    @MainActor
    func testSearchIsNilWhenQueryEmpty() {
        let viewModel = DuaViewModel(store: InMemoryStore())
        XCTAssertNil(viewModel.searchResults, "empty query must mean 'not searching', not 'no results'")
    }

    @MainActor
    func testSearchMatchesArabicTitleAndTranslation() {
        let viewModel = DuaViewModel(store: InMemoryStore())
        viewModel.setCategories([category("daily", duas: [istikhara, distress])])

        viewModel.searchQuery = "الاستخارة"
        XCTAssertEqual(viewModel.searchResults?.map(\.id), ["istikhara"])

        viewModel.searchQuery = "guidance"
        XCTAssertEqual(viewModel.searchResults?.map(\.id), ["istikhara"])
    }

    @MainActor
    func testSearchNoMatchesReturnsEmptyArrayNotNil() {
        let viewModel = DuaViewModel(store: InMemoryStore())
        viewModel.setCategories([category("daily", duas: [istikhara, distress])])
        viewModel.searchQuery = "xyzxyz-no-match"
        XCTAssertEqual(viewModel.searchResults, [])
    }

    @MainActor
    func testSearchWithResultsRecordsSearchHistoryOncePerDistinctQuery() async {
        let spy = SpySearchHistoryRecording()
        let viewModel = DuaViewModel(store: InMemoryStore(), searchHistory: spy)
        viewModel.setCategories([category("daily", duas: [istikhara, distress])])
        await viewModel.loadCategories(locale: "ar")

        viewModel.searchQuery = "الاستخارة"
        XCTAssertEqual(spy.recorded.count, 1)
        XCTAssertEqual(spy.recorded[0].source, "dua")
        XCTAssertEqual(spy.recorded[0].queryText, "الاستخارة")
        XCTAssertEqual(spy.recorded[0].locale, "ar")

        viewModel.searchQuery = "الاستخارة" // no-op re-set of the same query must not re-record
        XCTAssertEqual(spy.recorded.count, 1)
    }

    @MainActor
    func testSearchWithNoMatchesDoesNotRecordSearchHistory() {
        let spy = SpySearchHistoryRecording()
        let viewModel = DuaViewModel(store: InMemoryStore(), searchHistory: spy)
        viewModel.setCategories([category("daily", duas: [istikhara, distress])])

        viewModel.searchQuery = "xyzxyz-no-match"

        XCTAssertTrue(spy.recorded.isEmpty)
    }

    @MainActor
    func testToggleFavoriteTwiceRemovesIt() {
        let viewModel = DuaViewModel(store: InMemoryStore())
        XCTAssertFalse(viewModel.isFavorite("d1"))
        viewModel.toggleFavorite("d1")
        XCTAssertTrue(viewModel.isFavorite("d1"))
        viewModel.toggleFavorite("d1")
        XCTAssertFalse(viewModel.isFavorite("d1"))
    }

    @MainActor
    func testTogglingFavoriteFiresADistinctHapticForAddVersusRemove() {
        let haptics = SpyHaptics()
        let viewModel = DuaViewModel(store: InMemoryStore(), haptics: haptics)

        viewModel.toggleFavorite("d1")
        XCTAssertEqual(haptics.targetReachedCount, 1, "adding a favorite is the positive/reward moment")
        XCTAssertEqual(haptics.tickCount, 0)

        viewModel.toggleFavorite("d1")
        XCTAssertEqual(haptics.tickCount, 1, "removing is a lighter, distinct tick")
        XCTAssertEqual(haptics.targetReachedCount, 1)
    }

    @MainActor
    func testFavoritesPersistAcrossRestartsKeyedByStableId() {
        let store = InMemoryStore()
        let first = DuaViewModel(store: store)
        first.setCategories([category("daily", duas: [istikhara, distress])])
        first.toggleFavorite("istikhara")

        // Simulate app restart with a *different* category ordering (resync).
        let second = DuaViewModel(store: store)
        second.setCategories([category("daily", duas: [distress, istikhara])])

        XCTAssertTrue(second.isFavorite("istikhara"), "favorite must survive resync/reorder — keyed by id")
        XCTAssertEqual(second.favoriteDuas.map(\.id), ["istikhara"])
    }

    @MainActor
    func testEmptyFavoritesIsEmptyArray() {
        let viewModel = DuaViewModel(store: InMemoryStore())
        XCTAssertEqual(viewModel.favoriteDuas, [])
    }

    @MainActor
    func testMostRecentlyFavoritedFirst() {
        var clock = fixedNow
        let viewModel = DuaViewModel(store: InMemoryStore(), now: { clock })
        viewModel.setCategories([category("daily", duas: [istikhara, distress])])

        clock = fixedNow
        viewModel.toggleFavorite("istikhara")
        clock = fixedNow.addingTimeInterval(10)
        viewModel.toggleFavorite("distress")

        XCTAssertEqual(viewModel.favoriteDuas.map(\.id), ["distress", "istikhara"])
    }
}
