import AzkarFeature
import ConfigKit
import ContentKit
import CoreKit
import DuaFeature
import Factory
import Foundation
import NetworkingKit
import PrayerFeature
import PrayerKit
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

    @MainActor
    var prayerViewModel: Factory<PrayerViewModel> {
        self { @MainActor in
            PrayerViewModel(
                locationProvider: self.locationProvider(),
                scheduler: self.notificationScheduler(),
                widgetStore: self.widgetStore(),
                reloadWidgets: { WidgetCenter.shared.reloadAllTimelines() }
            )
        }
        .singleton
    }

    @MainActor
    var tasbeehViewModel: Factory<TasbeehViewModel> {
        self { @MainActor in
            TasbeehViewModel(
                haptics: SystemHaptics(),
                store: FileTasbeehHistoryStore(directory: AppEnvironment.sharedContainerURL)
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
                store: FileAzkarStore(directory: AppEnvironment.sharedContainerURL)
            )
        }
        .singleton
    }

    @MainActor
    var duaViewModel: Factory<DuaViewModel> {
        self { @MainActor in
            DuaViewModel(
                contentService: self.contentService(),
                store: FileDuaStore(directory: AppEnvironment.sharedContainerURL)
            )
        }
        .singleton
    }
}

enum AppEnvironment {
    /// Placeholder until the Supabase project exists (OPEN_QUESTIONS Q8);
    /// offline-first design means the app is fully functional without it.
    static let apiBaseURL = URL(string: "https://api.invalid/functions/v1/api")!

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
