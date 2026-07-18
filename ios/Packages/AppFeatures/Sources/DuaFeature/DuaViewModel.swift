import CoreKit
import ContentKit
import Foundation
import Observation

/// Library browse/search/favorite state (docs/features/dua.md). Pure over
/// injected store/clock for favorites; category loading from ContentKit is a
/// thin wrapper kept separate so search/favorite logic is unit-testable with
/// hand-built fixtures.
@MainActor
@Observable
public final class DuaViewModel {
    public private(set) var categories: [DuaCategory] = []
    public private(set) var isLoadingCategories = false
    public var searchQuery: String = "" {
        didSet { recordSearchIfNeeded() }
    }

    /// duaId -> addedAt. A dictionary (not an array-index) so favorites survive
    /// content resync — the spec's "keyed by stable duaId" requirement.
    private var favorites: [String: Date] = [:]

    private let contentService: ContentService?
    private let store: DuaStoring
    private let haptics: HapticsProviding
    private let now: @Sendable () -> Date
    private let searchHistory: SearchHistoryRecording
    private var locale = "ar"
    /// Dedupes recording on every keystroke that still resolves to the same
    /// completed query (e.g. focus loss re-triggering) — not a full debounce,
    /// but the spec explicitly allows either.
    private var lastRecordedQuery: String?

    public init(
        contentService: ContentService? = nil,
        store: DuaStoring,
        haptics: HapticsProviding = NoopHaptics(),
        now: @escaping @Sendable () -> Date = { Date() },
        searchHistory: SearchHistoryRecording = NoopSearchHistoryRecording()
    ) {
        self.contentService = contentService
        self.store = store
        self.haptics = haptics
        self.now = now
        self.searchHistory = searchHistory
        self.favorites = Dictionary(uniqueKeysWithValues: store.loadFavorites().map { ($0.duaId, $0.addedAt) })
    }

    public func loadCategories(locale: String) async {
        self.locale = locale
        guard let contentService else { return }
        isLoadingCategories = true
        setCategories(await contentService.duas(locale: locale)?.categories ?? [])
        isLoadingCategories = false
    }

    private func recordSearchIfNeeded() {
        guard let results = searchResults, !results.isEmpty, searchQuery != lastRecordedQuery else { return }
        lastRecordedQuery = searchQuery
        searchHistory.record(source: "dua", queryText: searchQuery, locale: locale)
    }

    /// Internal seam so search/favorite logic is testable without a live
    /// ContentService (mirrors AzkarViewModel.startSession taking items directly).
    func setCategories(_ categories: [DuaCategory]) {
        self.categories = categories
    }

    public var allDuas: [Dua] { categories.flatMap(\.duas) }

    /// Most-recently-favorited first.
    public var favoriteDuas: [Dua] {
        allDuas
            .filter { favorites[$0.id] != nil }
            .sorted { favorites[$0.id]! > favorites[$1.id]! }
    }

    public func isFavorite(_ duaId: String) -> Bool {
        favorites[duaId] != nil
    }

    public func toggleFavorite(_ duaId: String) {
        if favorites[duaId] != nil {
            favorites.removeValue(forKey: duaId)
            haptics.tick()
        } else {
            favorites[duaId] = now()
            haptics.targetReached()
        }
        store.saveFavorites(favorites.map { FavoriteDua(duaId: $0.key, addedAt: $0.value) })
    }

    /// `nil` means "not searching" (empty query); an empty array means
    /// "searched, no matches" — screens must distinguish these (spec §3).
    public var searchResults: [Dua]? {
        let normalized = DuaSearch.normalize(searchQuery)
        guard !normalized.isEmpty else { return nil }
        return allDuas.filter { dua in
            DuaSearch.normalize(dua.title).contains(normalized) ||
                DuaSearch.normalize(dua.arabicText).contains(normalized) ||
                (dua.translation.map { DuaSearch.normalize($0).contains(normalized) } ?? false)
        }
    }
}
