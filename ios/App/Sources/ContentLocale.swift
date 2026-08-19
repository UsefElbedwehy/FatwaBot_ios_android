import Foundation

/// The locale key every content read and every content sync must agree on.
///
/// This exists because they did not. `HadithCollectionsScreen` defaults its
/// `locale` parameter to `"ar"` and was constructed without one, while the
/// sync derived its key from `Locale.current` — so on an English device the
/// refresh wrote `hadith-collections.en` and the screen kept reading
/// `hadith-collections.ar`. Content synced correctly and was never displayed.
///
/// The expression was already duplicated at four call sites, which is what let
/// them drift. One definition, used everywhere.
enum ContentLocale {
    static var current: String {
        Locale.current.language.languageCode?.identifier ?? "ar"
    }
}
