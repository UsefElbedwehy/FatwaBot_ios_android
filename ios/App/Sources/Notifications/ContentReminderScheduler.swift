import AwradFeature
import ContentKit
import CoreKit
import Foundation
import PrayerKit
import UserNotifications

/// Registers the pure `ContentReminderPlanner` output with the OS.
///
/// Lives in the App target rather than a feature module because it composes two
/// packages that don't know about each other — ContentKit (the pool) and
/// PrayerKit (the notification budget) — which is exactly the composition role
/// ADR-0010 assigns to the app layer.
protocol ContentReminderScheduling: Sendable {
    func reschedule(preferences: ContentReminderPreferences, now: Date) async
}

final class ContentReminderScheduler: ContentReminderScheduling, @unchecked Sendable {
    /// Every reminder id starts with this, so clearing ours can't touch the
    /// prayer schedule's pending requests.
    static let idPrefix = "content-"

    /// `userInfo` keys carrying which specific item the notification showed —
    /// read back by `NotificationTapDelegate` so the tap can land on that item
    /// instead of just the Azkar/Hadith tab in general. Mirrors the shape of
    /// `WirdReminderScheduler.wirdIdKey`.
    static let contentIdKey = "contentId"
    static let categorySlugKey = "categorySlug"

    private let center: UNUserNotificationCenter
    private let contentService: ContentService
    private let stringProvider: @Sendable (String) -> String
    private let localeCode: @Sendable () -> String

    init(
        center: UNUserNotificationCenter = .current(),
        contentService: ContentService,
        stringProvider: @escaping @Sendable (String) -> String,
        localeCode: @escaping @Sendable () -> String = {
            Locale.current.language.languageCode?.identifier ?? "ar"
        }
    ) {
        self.center = center
        self.contentService = contentService
        self.stringProvider = stringProvider
        self.localeCode = localeCode
    }

    func reschedule(preferences: ContentReminderPreferences, now: Date = Date()) async {
        let locale = localeCode()
        let azkar = Self.azkarSnippets(await contentService.azkar(locale: locale), locale: locale)
        let hadith = await hadithSnippets(locale: locale)

        // The budget comes from the prayer planner's own constant rather than a
        // second hardcoded 48 — if that reservation ever changes, content
        // reminders shrink with it instead of pushing the total past iOS's 64
        // and silently evicting prayer notifications. The wird reminders take
        // their slice off the top for the same reason, and unconditionally: a
        // reservation that appeared only once the user enabled wird reminders
        // would overflow the cap the moment they did.
        let plan = ContentReminderPlanner.plan(
            azkar: azkar,
            hadith: hadith,
            preferences: preferences,
            now: now,
            calendar: .current,
            budget: WirdReminderPlanner.budgetAfterReserve(
                ContentReminderPlanner.remainingBudget(prayerReserve: NotificationPlanner.iosBudget)
            )
        )

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = stringProvider(item.titleKey)
            content.body = item.body
            content.sound = .default
            content.categoryIdentifier = "content." + item.kind.rawValue
            // What makes the tap land on the right screen — and the right ITEM
            // on it — read back by `NotificationTapDelegate`.
            var userInfo: [String: String] = [
                NotificationTapRouter.userInfoKey: item.deepLink.rawValue,
                Self.contentIdKey: item.contentID,
            ]
            userInfo[Self.categorySlugKey] = item.categorySlug
            content.userInfo = userInfo

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: - Pools

    /// Flattens every category's items. Which field is shown follows the app
    /// locale: an English reader gets the translation when there is one, and the
    /// Arabic falls back in when there isn't.
    static func azkarSnippets(_ collection: AzkarCollection?, locale: String) -> [ContentSnippet] {
        (collection?.categories ?? []).flatMap { category in
            category.items.compactMap { item -> ContentSnippet? in
                guard let text = preferredText(arabic: item.arabicText, translation: item.translation, locale: locale)
                else { return nil }
                // `category.id`, not `.slug` — `RemembranceScreen` selects by id.
                return ContentSnippet(id: item.id, categorySlug: category.id, text: text)
            }
        }
    }

    static func hadithSnippets(_ details: [HadithCollectionDetail], locale: String) -> [ContentSnippet] {
        details.flatMap { detail in
            detail.entries.compactMap { entry -> ContentSnippet? in
                guard let text = preferredText(arabic: entry.arabicText, translation: entry.translation, locale: locale)
                else { return nil }
                return ContentSnippet(id: entry.id, categorySlug: detail.slug, text: text)
            }
        }
    }

    static func preferredText(arabic: String, translation: String?, locale: String) -> String? {
        if locale.hasPrefix("en"), let translation, !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return translation
        }
        let trimmed = arabic.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func hadithSnippets(locale: String) async -> [ContentSnippet] {
        var details: [HadithCollectionDetail] = []
        for summary in await contentService.hadithCollections(locale: locale) {
            if let detail = await contentService.hadithDetail(slug: summary.slug, locale: locale) {
                details.append(detail)
            }
        }
        return Self.hadithSnippets(details, locale: locale)
    }
}
