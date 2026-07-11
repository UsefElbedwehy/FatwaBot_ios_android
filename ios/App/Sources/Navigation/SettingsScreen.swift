import DesignSystemKit
import Factory
import PrayerFeature
import SwiftUI

/// Settings tab, restyled as a profile-first screen (stakeholder direction,
/// 2026-07-11: "settings needs to be like profile as we will add login for
/// sure"). The account/login section is honestly a placeholder — no real
/// login exists yet (blocked on Q8 backend credentials) — rather than a
/// button that does nothing when tapped.
struct SettingsScreen: View {
    let prayerViewModel: PrayerViewModel
    @State private var isLiveActivityEnabled = Container.shared.liveActivityPreference().isEnabled()
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ProfileHeaderCard(tokens: tokens)

                VStack(alignment: .leading, spacing: 12) {
                    BrandSectionHeader("settings.prayer_section", systemImage: "moon.stars.fill", tokens: tokens)
                    Toggle(isOn: $isLiveActivityEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.live_activity.title")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(hexToken: tokens.onSurface))
                            Text("settings.live_activity.subtitle")
                                .font(.caption)
                                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        }
                    }
                    .tint(Color(hexToken: tokens.primary))
                    .onChange(of: isLiveActivityEnabled) { _, newValue in
                        prayerViewModel.setLiveActivityEnabled(newValue)
                    }
                    .brandCard(tokens)
                }

                VStack(alignment: .leading, spacing: 12) {
                    BrandSectionHeader("settings.about_section", systemImage: "info.circle.fill", tokens: tokens)
                    HStack {
                        Text("settings.about.version")
                            .foregroundStyle(Color(hexToken: tokens.onSurface))
                        Spacer()
                        Text(appVersion)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    }
                    .brandCard(tokens)
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
    }
}

private struct ProfileHeaderCard: View {
    let tokens: ColorTokens

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.primary).opacity(0.75)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hexToken: tokens.onPrimary))
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("settings.profile.guest_name")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                Label("settings.profile.sign_in_coming_soon", systemImage: "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hexToken: tokens.accent))
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hexToken: tokens.primaryContainer), Color(hexToken: tokens.surfaceElevated)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hexToken: tokens.primary).opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color(hexToken: tokens.primary).opacity(0.10), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}
