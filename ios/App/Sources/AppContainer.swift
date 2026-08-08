import AwradFeature
import AzkarFeature
import ConfigKit
import ContentKit
import CoreKit
import DuaFeature
import Factory
import Foundation
import GamificationFeature
import HadithFeature
import LeaderboardFeature
import NetworkingKit
import OnboardingFeature
import PrayerFeature
import PrayerKit
import SearchHistoryFeature
import TasbeehFeature
import WidgetKit

/// Composition root (ADR-0006). Feature code receives dependencies; only this
/// file knows concrete wiring. Test overrides via Container scopes.
extension Container {
    var apiClient: Factory<APIClientProtocol> {
        self {
            APIClient(
                baseURL: AppEnvironment.apiBaseURL,
                context: ClientContext(
                    appVersion: AppEnvironment.appVersion,
                    locale: Locale.preferredLanguages.first ?? "ar"
                )
            )
        }
        .singleton
    }

    var configService: Factory<ConfigService> {
        self {
            ConfigService(
                store: FileConfigStore(directory: AppEnvironment.sharedContainerURL),
                client: self.apiClient()
            )
        }
        .singleton
    }

    var contentService: Factory<ContentService> {
        self {
            ContentService(
                store: ContentFileStore(directory: AppEnvironment.sharedContainerURL),
                client: self.apiClient()
            )
        }
        .singleton
    }

    var locationProvider: Factory<LocationProviding> {
        self { SystemLocationProvider() }.singleton
    }

    /// Product analytics through our OWN ingest — no third-party SDK on iOS
    /// (docs/features/analytics-and-crash-reporting.md). Batched + disk-queued,
    /// and gated on the user's Settings choice, read fresh on every call so
    /// revoking consent takes effect immediately.
    var analyticsTracking: Factory<AnalyticsTracking> {
        self {
            BackendAnalyticsRecorder(
                store: FileAnalyticsEventQueueStore(directory: AppEnvironment.sharedContainerURL),
                client: self.authenticatedClient(),
                appVersion: AppEnvironment.appVersion,
                isEnabled: { AnalyticsPreferences.isEnabled() }
            )
        }.singleton
    }

    var onboardingCompletionStore: Factory<OnboardingCompletionStore> {
        self { OnboardingCompletionStore(directory: AppEnvironment.sharedContainerURL) }
    }

    var authTokenStore: Factory<AuthTokenStoring> {
        self { KeychainAuthTokenStore() }.singleton
    }

    var authService: Factory<AuthTokenProviding> {
        self {
            AuthService(
                baseURL: AppEnvironment.apiBaseURL,
                context: ClientContext(
                    appVersion: AppEnvironment.appVersion,
                    locale: Locale.preferredLanguages.first ?? "ar"
                ),
                store: self.authTokenStore()
            )
        }
        .singleton
    }

    var authenticatedClient: Factory<AuthenticatedAPIClientProtocol> {
        self {
            AuthenticatedAPIClient(
                baseURL: AppEnvironment.apiBaseURL,
                context: ClientContext(
                    appVersion: AppEnvironment.appVersion,
                    locale: Locale.preferredLanguages.first ?? "ar"
                ),
                tokenProvider: self.authService()
            )
        }
        .singleton
    }

    /// Account reads/writes (`/v1/me`, profile, provider link).
    var accountService: Factory<AccountServicing> {
        self { AccountService(client: self.authenticatedClient()) }.singleton
    }

    /// Provider identity-token source — both real now: Apple via
    /// ASAuthorizationController, Google via the GoogleSignIn SDK. Each returns
    /// a signed token the backend verifies against the provider's JWKS.
    var providerCredential: Factory<ProviderCredentialProviding> {
        self {
            CompositeCredentialProvider(
                apple: AppleCredentialProvider(),
                google: GoogleCredentialProvider()
            )
        }
        .singleton
    }

    /// Concrete recorder, shared by GamificationViewModel (to flush before a
    /// profile read) and every feature ViewModel injected via the CoreKit
    /// `ActivityEventRecording` boundary below.
    var gamificationEventRecorder: Factory<GamificationEventRecorder> {
        self {
            GamificationEventRecorder(
                store: FileActivityEventQueueStore(directory: AppEnvironment.sharedContainerURL),
                client: self.authenticatedClient()
            )
        }
        .singleton
    }

    /// The CoreKit boundary Tasbeeh/Azkar/Awrad/Hadith are actually injected
    /// with (ADR-0010: feature -> feature is forbidden, mirrors HapticsProviding).
    var activityEventRecording: Factory<ActivityEventRecording> {
        self { self.gamificationEventRecorder() }
    }

    var notificationScheduler: Factory<PrayerNotificationScheduling> {
        self {
            // M1: bundled notification texts. Admin-editable template packs
            // (ADR-0013) overlay here when the campaign engine ships in M3.
            PrayerNotificationScheduler(stringProvider: { key in
                NSLocalizedString(key, comment: "")
            })
        }
        .singleton
    }

    /// Daily azkar/hadith reminders. Separate from `notificationScheduler`
    /// because it owns a different id namespace and a different budget slice —
    /// one scheduler clearing the other's pending requests is the bug this split
    /// avoids.
    var contentReminderScheduler: Factory<ContentReminderScheduling> {
        self {
            ContentReminderScheduler(
                contentService: self.contentService(),
                stringProvider: { key in NSLocalizedString(key, comment: "") }
            )
        }
        .singleton
    }

    var contentReminderPreferenceStore: Factory<ContentReminderPreferenceStoring> {
        self { UserDefaultsContentReminderPreferenceStore() }.singleton
    }

    /// The wird store, hoisted out of `awradViewModel` so the notification
    /// action path and the UI path write through the SAME object. A second
    /// `FileWirdStore` over the same directory would work too, but sharing one
    /// makes the "one source of truth" explicit.
    ///
    /// Wrapped in `SeededWirdStore` so the four fixed slots (`FixedWirdSlot`)
    /// exist for every user on every read — existing installs included, not just
    /// fresh ones. The names are resolved here because the localized strings live
    /// in the app bundle, and they are frozen into the record at seeding time,
    /// exactly like a template-created wird's name.
    var wirdStore: Factory<WirdStoring> {
        self {
            SeededWirdStore(
                wrapping: FileWirdStore(directory: AppEnvironment.sharedContainerURL),
                name: { slot in NSLocalizedString(slot.nameKey, comment: "") }
            )
        }
        .singleton
    }

    /// Applies a notification "نعم" straight to the store. Resolvable off the
    /// main actor: it is what runs when the app is backgrounded or not running,
    /// where no `AwradViewModel` exists.
    var wirdCompletionResponder: Factory<WirdCompletionResponder> {
        self {
            WirdCompletionResponder(
                store: self.wirdStore(),
                activityEvents: self.activityEventRecording()
            )
        }
    }

    /// Daily "did you complete your wird?" reminders. A third id namespace and a
    /// third budget slice, kept apart from prayer and content for the same reason
    /// those two are apart — one scheduler clearing another's pending requests.
    var wirdReminderScheduler: Factory<WirdReminderScheduling> {
        self {
            WirdReminderScheduler(stringProvider: { key in NSLocalizedString(key, comment: "") })
        }
        .singleton
    }

    var wirdReminderPreferenceStore: Factory<WirdReminderPreferenceStoring> {
        self { UserDefaultsWirdReminderPreferenceStore() }.singleton
    }

    var widgetStore: Factory<WidgetSnapshotStore?> {
        self {
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.fatwabot.app")
                .map { WidgetSnapshotStore(appGroupContainer: $0) }
        }
    }

    /// Where the متابعة العبادات widget deposits taps for the app to upload.
    var worshipInbox: Factory<WorshipInbox?> {
        self {
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.fatwabot.app")
                .map { WorshipInbox(appGroupContainer: $0) }
        }
    }

    var gamificationWidgetStore: Factory<GamificationWidgetSnapshotStore?> {
        self {
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.fatwabot.app")
                .map { GamificationWidgetSnapshotStore(appGroupContainer: $0) }
        }
    }

    var liveActivityManager: Factory<PrayerLiveActivityManaging> {
        self { SystemPrayerLiveActivityManager() }.singleton
    }

    var liveActivityPreference: Factory<LiveActivityPreferenceStoring> {
        self { UserDefaultsLiveActivityPreferenceStore() }.singleton
    }

    @MainActor
    var prayerViewModel: Factory<PrayerViewModel> {
        self { @MainActor in
            PrayerViewModel(
                locationProvider: self.locationProvider(),
                scheduler: self.notificationScheduler(),
                widgetStore: self.widgetStore(),
                reloadWidgets: { WidgetCenter.shared.reloadAllTimelines() },
                liveActivity: self.liveActivityManager(),
                liveActivityPreference: self.liveActivityPreference()
            )
        }
        .singleton
    }

    @MainActor
    var tasbeehViewModel: Factory<TasbeehViewModel> {
        self { @MainActor in
            TasbeehViewModel(
                haptics: SystemHaptics(),
                store: FileTasbeehHistoryStore(directory: AppEnvironment.sharedContainerURL),
                activityEvents: self.activityEventRecording()
            )
        }
        .singleton
    }

    @MainActor
    var azkarViewModel: Factory<AzkarViewModel> {
        self { @MainActor in
            AzkarViewModel(
                contentService: self.contentService(),
                haptics: SystemHaptics(),
                store: FileAzkarStore(directory: AppEnvironment.sharedContainerURL),
                activityEvents: self.activityEventRecording()
            )
        }
        .singleton
    }

    @MainActor
    var duaViewModel: Factory<DuaViewModel> {
        self { @MainActor in
            DuaViewModel(
                contentService: self.contentService(),
                store: FileDuaStore(directory: AppEnvironment.sharedContainerURL),
                haptics: SystemHaptics(),
                searchHistory: self.searchHistoryRecorder()
            )
        }
        .singleton
    }

    @MainActor
    var awradViewModel: Factory<AwradViewModel> {
        self { @MainActor in
            AwradViewModel(
                contentService: self.contentService(),
                store: self.wirdStore(),
                haptics: SystemHaptics(),
                activityEvents: self.activityEventRecording()
            )
        }
        .singleton
    }

    @MainActor
    var hadithViewModel: Factory<HadithViewModel> {
        self { @MainActor in
            HadithViewModel(
                contentService: self.contentService(),
                store: FileHadithStore(directory: AppEnvironment.sharedContainerURL),
                haptics: SystemHaptics(),
                activityEvents: self.activityEventRecording()
            )
        }
        .singleton
    }

    @MainActor
    var gamificationViewModel: Factory<GamificationViewModel> {
        self { @MainActor in
            GamificationViewModel(
                client: self.authenticatedClient(),
                recorder: self.gamificationEventRecorder(),
                widgetStore: self.gamificationWidgetStore(),
                reloadWidgets: { WidgetCenter.shared.reloadAllTimelines() }
            )
        }
        .singleton
    }

    @MainActor
    var leaderboardViewModel: Factory<LeaderboardViewModel> {
        self { @MainActor in
            LeaderboardViewModel(
                client: self.authenticatedClient(),
                haptics: SystemHaptics(),
                // Reuses what prayer times already resolved: `UserLocation`
                // carries the reverse-geocoded locality and country code, so
                // joining a regional board costs no geocode, no network call,
                // and no second permission prompt.
                region: ClosureRegionResolver { [provider = self.locationProvider()] in
                    guard let cached = provider.cached() else { return .unknown }
                    return LeaderboardRegion(
                        city: cached.name,
                        countryCode: cached.countryCode?.uppercased()
                    )
                }
            )
        }
    }

    /// The CoreKit boundary Dua (and any future searchable feature) is
    /// actually injected with (ADR-0010, mirrors activityEventRecording).
    var searchHistoryRecorder: Factory<SearchHistoryRecording> {
        self { SearchHistoryRecorder(client: self.authenticatedClient()) }
            .singleton
    }

    @MainActor
    var searchHistoryViewModel: Factory<SearchHistoryViewModel> {
        self { @MainActor in SearchHistoryViewModel(client: self.authenticatedClient(), haptics: SystemHaptics()) }
    }
}

enum AppEnvironment {
    /// Placeholder until the Supabase project exists (OPEN_QUESTIONS Q8);
    /// offline-first design means the app is fully functional without it.
    static let apiBaseURL = URL(string: "https://nbeobnlgsbokomvkmzeq.supabase.co/functions/v1/api")!

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// App-group container once widgets land (M1 widgets task); Application
    /// Support until the entitlement is configured.
    static var sharedContainerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.fatwabot.app"
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
