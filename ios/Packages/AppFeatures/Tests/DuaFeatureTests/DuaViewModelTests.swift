import XCTest
import ContentKit
@testable import DuaFeature

final class DuaViewModelTests: XCTestCase {
    final class InMemoryStore: DuaStoring, @unchecked Sendable {
        var favorites: [FavoriteDua] = []
        func loadFavorites() -> [FavoriteDua] { favorites }
        func saveFavorites(_ favorites: [FavoriteDua]) { self.favorites = favorites }
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
    func testToggleFavoriteTwiceRemovesIt() {
        let viewModel = DuaViewModel(store: InMemoryStore())
        XCTAssertFalse(viewModel.isFavorite("d1"))
        viewModel.toggleFavorite("d1")
        XCTAssertTrue(viewModel.isFavorite("d1"))
        viewModel.toggleFavorite("d1")
        XCTAssertFalse(viewModel.isFavorite("d1"))
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
