import DesignSystemKit
import Factory
import PrayerFeature
import PrayerKit
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

                NotificationsSection(prayerViewModel: prayerViewModel, tokens: tokens)

                FeaturesGuideSection(tokens: tokens)

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

/// Per-type notification controls — every notification can be toggled on/off,
/// and the pre-adhan/iqama offsets are user-set (stakeholder direction,
/// 2026-07-12). Edits persist and reschedule immediately via the ViewModel.
private struct NotificationsSection: View {
    let prayerViewModel: PrayerViewModel
    let tokens: ColorTokens
    @State private var prefs: PrayerNotificationPreferences

    init(prayerViewModel: PrayerViewModel, tokens: ColorTokens) {
        self.prayerViewModel = prayerViewModel
        self.tokens = tokens
        _prefs = State(initialValue: prayerViewModel.notificationPreferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.notifications_section", systemImage: "bell.badge.fill", tokens: tokens)
            VStack(spacing: 14) {
                toggleRow("settings.notif.adhan.title", "settings.notif.adhan.subtitle", isOn: $prefs.adhanEnabled)
                Divider().opacity(0.3)
                toggleRow("settings.notif.pre_adhan.title", "settings.notif.pre_adhan.subtitle", isOn: $prefs.preAdhanEnabled)
                if prefs.preAdhanEnabled {
                    offsetRow("settings.notif.minutes_before", value: $prefs.preAdhanOffsetMinutes)
                }
                Divider().opacity(0.3)
                toggleRow("settings.notif.iqama.title", "settings.notif.iqama.subtitle", isOn: $prefs.iqamaEnabled)
                if prefs.iqamaEnabled {
                    offsetRow("settings.notif.minutes_after", value: $prefs.iqamaOffsetMinutes)
                }
                Divider().opacity(0.3)
                toggleRow("settings.notif.last_third.title", "settings.notif.last_third.subtitle", isOn: $prefs.lastThirdEnabled)
            }
            .brandCard(tokens)
            .onChange(of: prefs) { _, newValue in
                prayerViewModel.setNotificationPreferences(newValue)
            }
        }
    }

    private func toggleRow(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(Color(hexToken: tokens.onSurface))
                Text(subtitle).font(.caption).foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
        }
        .tint(Color(hexToken: tokens.primary))
    }

    private func offsetRow(_ label: LocalizedStringKey, value: Binding<Int>) -> some View {
        Stepper(value: value, in: PrayerNotificationPreferences.offsetRange) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                Spacer()
                Text("settings.notif.minutes_value \(value.wrappedValue)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
        }
    }
}

/// The "?" features guide (stakeholder direction, 2026-07-12): a per-item
/// explanation of what each notification/feature does, so users understand them.
private struct FeaturesGuideSection: View {
    let tokens: ColorTokens

    private struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let items: [Item] = [
        .init(icon: "megaphone.fill", title: "settings.notif.adhan.title", body: "settings.guide.adhan"),
        .init(icon: "bell.fill", title: "settings.notif.pre_adhan.title", body: "settings.guide.pre_adhan"),
        .init(icon: "person.3.fill", title: "settings.notif.iqama.title", body: "settings.guide.iqama"),
        .init(icon: "moon.stars.fill", title: "settings.notif.last_third.title", body: "settings.guide.last_third"),
        .init(icon: "lock.fill", title: "settings.live_activity.title", body: "settings.guide.live_activity"),
        .init(icon: "flame", title: "gamification.streaks_section", body: "settings.guide.streaks"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.guide_section", systemImage: "questionmark.circle.fill", tokens: tokens)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DisclosureGroup {
                        Text(item.body)
                            .font(.caption)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    } label: {
                        Label {
                            Text(item.title).font(.body.weight(.medium))
                                .foregroundStyle(Color(hexToken: tokens.onSurface))
                        } icon: {
                            Image(systemName: item.icon).foregroundStyle(Color(hexToken: tokens.primary))
                        }
                        .padding(.vertical, 8)
                    }
                    .tint(Color(hexToken: tokens.primary))
                    if index < items.count - 1 { Divider().opacity(0.3) }
                }
            }
            .brandCard(tokens)
        }
    }
}
