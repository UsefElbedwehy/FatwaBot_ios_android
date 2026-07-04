import ConfigKit
import Factory
import Foundation
import NetworkingKit
import PrayerFeature
import PrayerKit

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

    var locationProvider: Factory<LocationProviding> {
        self { SystemLocationProvider() }.singleton
    }

    @MainActor
    var prayerViewModel: Factory<PrayerViewModel> {
        self { @MainActor in
            PrayerViewModel(locationProvider: self.locationProvider())
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
