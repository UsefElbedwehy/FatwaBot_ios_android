import DesignSystemKit
import Factory
import NetworkingKit
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
                AccountSection(tokens: tokens)

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

/// Account/profile section: shows the current identity (guest or linked),
/// lets the user set a display name (works today against `/v1/me/profile`),
/// and — when still a guest — offers Sign in with Apple / Google, which link
/// the anonymous identity without losing any progress (docs/features/accounts.md).
private struct AccountSection: View {
    let tokens: ColorTokens
    @StateObject private var viewModel = AccountViewModel(
        account: Container.shared.accountService(),
        credentials: Container.shared.providerCredential()
    )
    @State private var isEditingName = false
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerCard
            if isEditingName {
                nameEditor
            }
            if !viewModel.isSignedIn {
                signInButtons
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
        .task { await viewModel.load() }
    }

    private var displayName: String {
        if let name = viewModel.profile?.displayName, !name.isEmpty { return name }
        return String(localized: "settings.profile.guest_name")
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(
                    LinearGradient(
                        colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.primary).opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                Image(systemName: viewModel.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color(hexToken: tokens.onPrimary))
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                Label(viewModel.providerLabel, systemImage: viewModel.isSignedIn ? "checkmark.seal.fill" : "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hexToken: tokens.accent))
            }
            Spacer(minLength: 0)

            Button {
                draftName = viewModel.profile?.displayName ?? ""
                withAnimation { isEditingName.toggle() }
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .frame(width: 36, height: 36)
                    .background(Color(hexToken: tokens.primary).opacity(0.12), in: Circle())
            }
            .accessibilityLabel("settings.account.edit_name")
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
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("settings.account.name_placeholder", text: $draftName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(hexToken: tokens.surface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack {
                Spacer()
                Button("settings.account.cancel") { withAnimation { isEditingName = false } }
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                Button("settings.account.save") {
                    Task {
                        await viewModel.saveDisplayName(draftName)
                        withAnimation { isEditingName = false }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color(hexToken: tokens.primary))
                .disabled(viewModel.isBusy)
            }
        }
        .brandCard(tokens)
    }

    private var signInButtons: some View {
        VStack(spacing: 10) {
            if viewModel.isAvailable(.apple) {
                signInButton(.apple, title: "settings.account.sign_in_apple", systemImage: "apple.logo")
            }
            if viewModel.isAvailable(.google) {
                signInButton(.google, title: "settings.account.sign_in_google", systemImage: "g.circle.fill")
            }
        }
    }

    private func signInButton(_ provider: AccountProvider, title: LocalizedStringKey, systemImage: String) -> some View {
        Button {
            Task { await viewModel.signIn(with: provider) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color(hexToken: tokens.onPrimary))
            .background(Color(hexToken: tokens.primary), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(viewModel.isBusy)
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
