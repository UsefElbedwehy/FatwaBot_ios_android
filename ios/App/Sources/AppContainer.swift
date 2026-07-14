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

    /// Provider identity-token source. Stub today (works against the backend's
    /// dev verifier); swap to native Apple/Google once credentials exist.
    var providerCredential: Factory<ProviderCredentialProviding> {
        self { StubProviderCredentialProvider() }.singleton
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

    var widgetStore: Factory<WidgetSnapshotStore?> {
        self {
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.fatwabot.app")
                .map { WidgetSnapshotStore(appGroupContainer: $0) }
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
                store: FileWirdStore(directory: AppEnvironment.sharedContainerURL),
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
        self { @MainActor in LeaderboardViewModel(client: self.authenticatedClient(), haptics: SystemHaptics()) }
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
