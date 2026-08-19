import AwradFeature
import ContentKit
import DesignSystemKit
import Factory
import NetworkingKit
import PrayerFeature
import PrayerKit
import SwiftUI
import UIKit

/// Settings tab, restyled as a profile-first screen (stakeholder direction,
/// 2026-07-11: "settings needs to be like profile as we will add login for
/// sure"). The account/login section is honestly a placeholder — no real
/// login exists yet (blocked on Q8 backend credentials) — rather than a
/// button that does nothing when tapped.
struct SettingsScreen: View {
    let prayerViewModel: PrayerViewModel
    /// Resolved in the composition root (RootTabView) from the config string
    /// packs, so this screen — and the design system it draws with — stay clear
    /// of any config/network dependency (ADR-0010).
    let contact: ContactLinks
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

                AppearanceSection(tokens: tokens)

                LanguageSection(tokens: tokens)

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

                DiagnosticsSection(tokens: tokens)
                ContentSyncSection(tokens: tokens)

                // Hidden entirely while the dashboard has supplied no channel —
                // an empty "Contact" header helps nobody.
                if !contact.isEmpty {
                    ContactSection(links: contact, tokens: tokens)
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
    /// A native `DatePicker` in its compact style, sitting inside an Arabic
    /// (RTL) layout, silently stops responding to taps — reproduced live on
    /// device/simulator with the system language set to Arabic; the identical
    /// row works fine under English. Forcing `.environment(\.layoutDirection,
    /// .leftToRight)` and `.environment(\.calendar, .gregorian)` on the picker
    /// were both tried and neither fixed it, so rather than depend on
    /// compact-`DatePicker`'s undocumented RTL hit-testing, these rows drive
    /// their own sheet — the same shape as Android's `TimePickerDialog` rows,
    /// which never had this problem.
    private enum TimeEditTarget: Identifiable, Equatable {
        case slot(FixedWirdSlot)
        case otherWirds

        var id: String {
            switch self {
            case .slot(let slot): slot.wirdId
            case .otherWirds: "other-wirds"
            }
        }
    }

    let prayerViewModel: PrayerViewModel
    let tokens: ColorTokens
    @State private var prefs: PrayerNotificationPreferences
    @State private var contentPrefs: ContentReminderPreferences
    @State private var wirdPrefs: WirdReminderPreferences
    @State private var timeEditTarget: TimeEditTarget?
    // Optimistic default: most sessions are authorized, and this only ever
    // matters once the real check comes back — starting `.denied` would flash
    // a banner that immediately disappears on every normal launch.
    @State private var authStatus: NotificationAuthorization = .authorized

    private let contentStore = Container.shared.contentReminderPreferenceStore()
    private let wirdStore = Container.shared.wirdReminderPreferenceStore()

    init(prayerViewModel: PrayerViewModel, tokens: ColorTokens) {
        self.prayerViewModel = prayerViewModel
        self.tokens = tokens
        _prefs = State(initialValue: prayerViewModel.notificationPreferences)
        _contentPrefs = State(initialValue: Container.shared.contentReminderPreferenceStore().load())
        _wirdPrefs = State(initialValue: Container.shared.wirdReminderPreferenceStore().load())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.notifications_section", systemImage: "bell.badge.fill", tokens: tokens)
            if authStatus == .denied {
                notificationsDisabledBanner
            }
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
                    // The gap differs per prayer in practice, so each gets its own
                    // stepper. The notice explains why there are five rows here
                    // rather than the single one this used to be.
                    InfoNotice(String(localized: "settings.notif.iqama.notice"), tokens: tokens)
                    ForEach(PrayerName.allCases.filter(\.isPrayer), id: \.self) { prayer in
                        iqamaRow(for: prayer)
                    }
                }
                Divider().opacity(0.3)
                toggleRow("settings.notif.last_third.title", "settings.notif.last_third.subtitle", isOn: $prefs.lastThirdEnabled)
                Divider().opacity(0.3)
                // Daily azkar/hadith reminders at random waking-hour times.
                toggleRow("settings.notif.content.title", "settings.notif.content.subtitle", isOn: $contentPrefs.enabled)
                if contentPrefs.enabled {
                    countRow("settings.notif.content.per_day", value: $contentPrefs.perDay)
                }
                Divider().opacity(0.3)
                // One "did you complete it?" notification per active wird, once a
                // day, answerable straight from the notification.
                toggleRow("settings.notif.wird.title", "settings.notif.wird.subtitle", isOn: $wirdPrefs.enabled)
                if wirdPrefs.enabled {
                    // The four fixed slots each get their own time (client
                    // request). They are on every board and their natural
                    // moments are hours apart — asking about أذكار الصباح at the
                    // same time as قيام الليل is asking about a window that
                    // closed. User-created wirds keep the shared time below.
                    ForEach(FixedWirdSlot.allCases, id: \.rawValue) { slot in
                        // An anchored slot follows its prayer, so its clock
                        // picker is hidden rather than shown-but-ignored.
                        if wirdPrefs.prayerAnchor(forWirdId: slot.wirdId) == nil {
                            slotTimeRow(slot)
                        }
                        slotAnchorRow(slot)
                    }
                    Divider().opacity(0.3)
                    timeRow("settings.notif.wird.time_other")
                }
            }
            .brandCard(tokens)
            .onChange(of: prefs) { _, newValue in
                prayerViewModel.setNotificationPreferences(newValue)
            }
            .onChange(of: contentPrefs) { _, newValue in
                contentStore.save(newValue)
                // Re-plan immediately so turning it off actually cancels today's
                // pending reminders rather than waiting for the next launch.
                Task {
                    await Container.shared.contentReminderScheduler()
                        .reschedule(preferences: newValue, now: Date())
                }
            }
            .onChange(of: wirdPrefs) { _, newValue in
                wirdStore.save(newValue)
                // Same reasoning as the content reminders: turning it off has to
                // cancel what is already pending, and a new time has to move the
                // pending requests rather than wait for the next launch.
                Task {
                    await Container.shared.wirdReminderScheduler().reschedule(
                        preferences: newValue,
                        wirds: Container.shared.wirdStore().loadWirds(),
                        // Resolved here, on the main actor, rather than inside
                        // the closure. `MainActor.assumeIsolated` traps when the
                        // closure is invoked from the planner's async context —
                        // it crashed the app the moment the switch was tapped.
                        prayerTime: WirdAnchorTimes.lookup(from: prayerViewModel)
                    )
                }
            }
            .sheet(item: $timeEditTarget) { target in
                timeEditSheet(for: target)
                    .presentationDetents([.height(280)])
            }
            .task {
                // Checks the *current* OS permission rather than trusting the
                // one-time prompt at launch — the only way to notice a user
                // revoked it later from iOS Settings, which otherwise looks
                // identical to every notification just silently not arriving.
                authStatus = await prayerViewModel.notificationAuthorizationStatus()
            }
        }
    }

    /// Shown only when the OS permission is actually `.denied` — every toggle
    /// below keeps building a schedule that will never surface, with nothing
    /// else on screen explaining why.
    private var notificationsDisabledBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 17))
                .foregroundStyle(Color(hexToken: tokens.primary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("settings.notif.disabled_banner")
                    .font(.footnote)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .fixedSize(horizontal: false, vertical: true)
                Button("settings.notif.disabled_banner_action") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.primary))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            Color(hexToken: tokens.primaryContainer).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    /// The wheel picker shown for whichever row's pill was tapped. One sheet,
    /// reused for every slot plus the "other wirds" row, driven by
    /// `timeEditTarget`.
    private func timeEditTitle(for target: TimeEditTarget) -> LocalizedStringKey {
        switch target {
        case .slot(let slot): LocalizedStringKey(slot.nameKey)
        case .otherWirds: "settings.notif.wird.time_other"
        }
    }

    private func timeEditBinding(for target: TimeEditTarget) -> Binding<Date> {
        switch target {
        case .slot(let slot): slotTimeBinding(slot)
        case .otherWirds: otherWirdsTimeBinding
        }
    }

    private func timeEditSheet(for target: TimeEditTarget) -> some View {
        let title = timeEditTitle(for: target)
        let binding = timeEditBinding(for: target)
        return NavigationStack {
            DatePicker(selection: binding, displayedComponents: .hourAndMinute) {
                EmptyView()
            }
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding(.top, 8)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { timeEditTarget = nil }
                }
            }
        }
    }

    /// Time-of-day picker for one fixed wird slot.
    ///
    /// Shows the slot's built-in hour until the user picks something, so the
    /// control never reads as unset — and picking a time writes an override that
    /// then wins over the built-in default forever.
    /// "Follow the prayer" switch for the slots that have a natural anchor.
    @ViewBuilder
    private func slotAnchorRow(_ slot: FixedWirdSlot) -> some View {
        if let prayer = slot.anchorPrayer {
            let isAnchored = wirdPrefs.prayerAnchor(forWirdId: slot.wirdId) != nil
            Toggle(isOn: Binding(
                get: { isAnchored },
                set: { on in
                    wirdPrefs = on
                        ? wirdPrefs.settingPrayerAnchor(
                            prayer: prayer,
                            offsetMinutes: slot.defaultAnchorOffsetMinutes,
                            forWirdId: slot.wirdId
                        )
                        : wirdPrefs.clearingPrayerAnchor(forWirdId: slot.wirdId)
                }
            )) {
                // The slot name is on this row, not only on the time picker.
                // Anchoring hides that picker, and with it went the only thing
                // saying which wird the switch belonged to — a bare "Follow Fajr
                // time" floating under the previous slot's row.
                VStack(alignment: .leading, spacing: 1) {
                    Text(NSLocalizedString(slot.nameKey, comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                    Text(String(
                        format: NSLocalizedString("settings.notif.wird.follow_prayer", comment: ""),
                        NSLocalizedString("prayer.\(prayer)", comment: "")
                    ))
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
            }
            .tint(Color(hexToken: tokens.primary))
        }
    }

    private func slotTimeBinding(_ slot: FixedWirdSlot) -> Binding<Date> {
        Binding<Date>(
            get: {
                let time = wirdPrefs.time(
                    forWirdId: slot.wirdId, slotDefaultHour: slot.reminderHour
                )
                return Calendar.current.date(
                    from: DateComponents(hour: time.hour, minute: time.minute)
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                wirdPrefs = wirdPrefs.settingTime(
                    WirdReminderTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0),
                    forWirdId: slot.wirdId
                )
            }
        )
    }

    private func slotTimeRow(_ slot: FixedWirdSlot) -> some View {
        timePillRow(
            label: Text(NSLocalizedString(slot.nameKey, comment: "")),
            date: slotTimeBinding(slot).wrappedValue,
            target: .slot(slot)
        )
    }

    /// Time-of-day picker for the wird reminder. Bound through a `Date` because
    /// that is what `DatePicker` speaks, while the preference persists as plain
    /// hour/minute — a stored `Date` would carry a calendar day with it and drift.
    private var otherWirdsTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: wirdPrefs.hour, minute: wirdPrefs.minute)
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                // Mutated rather than re-constructed. The memberwise initialiser
                // defaults `timesByWird` to empty, so building a fresh value here
                // silently erased every per-wird time the user had set the moment
                // they nudged the global one.
                wirdPrefs.hour = WirdReminderPreferences.clampHour(
                    parts.hour ?? WirdReminderPreferences.defaultHour
                )
                wirdPrefs.minute = WirdReminderPreferences.clampMinute(
                    parts.minute ?? WirdReminderPreferences.defaultMinute
                )
            }
        )
    }

    /// Time-of-day picker for the wird reminder. Bound through a `Date` because
    /// that is what `DatePicker` speaks, while the preference persists as plain
    /// hour/minute — a stored `Date` would carry a calendar day with it and drift.
    private func timeRow(_ label: LocalizedStringKey) -> some View {
        timePillRow(label: Text(label), date: otherWirdsTimeBinding.wrappedValue, target: .otherWirds)
    }

    /// A label plus a tappable pill showing the current time, opening
    /// `timeEditSheet` on tap. Replaces a bare `DatePicker` — see the comment
    /// on `TimeEditTarget` for why.
    private func timePillRow(label: Text, date: Date, target: TimeEditTarget) -> some View {
        HStack {
            label
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            Spacer()
            Button {
                timeEditTarget = target
            } label: {
                Text(date, style: .time)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Color(hexToken: tokens.onSurface).opacity(0.08),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// Stepper for "how many reminders a day", 0–5. Same shape as `offsetRow`
    /// but over a count rather than minutes, so the unit label differs.
    private func countRow(_ label: LocalizedStringKey, value: Binding<Int>) -> some View {
        Stepper(value: value, in: ContentReminderPreferences.countRange) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                Spacer()
                Text("settings.notif.content.count_value \(value.wrappedValue)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
        }
    }

    /// One stepper per prayer, bound through the offsets dictionary. Falls back to
    /// the mosque default when a key is absent, so a partially populated
    /// dictionary still renders a sane value instead of zero.
    private func iqamaRow(for prayer: PrayerName) -> some View {
        let binding = Binding(
            get: { prefs.iqamaOffset(for: prayer) },
            set: { prefs.iqamaOffsetsByPrayer[prayer.rawValue] = $0 }
        )
        return offsetRow(LocalizedStringKey("prayer.\(prayer.rawValue)"), value: binding)
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
/// Appearance control — System / Light / Dark, applied app-wide via
/// `preferredColorScheme` in FatwaBotApp (bound to the same @AppStorage key).
/// Diagnostics opt-out. Usage reporting is on by default — it's what tells us
/// which worship features earn their place, and nothing personal is collected
/// (see `CoreKit.AnalyticsTracking`). The switch exists because this is a worship
/// app: someone who would rather send nothing at all shouldn't have to uninstall
/// to get that. Opting out also drops anything still queued, so events recorded
/// before the decision are never transmitted afterwards.
private struct DiagnosticsSection: View {
    let tokens: ColorTokens
    @AppStorage(AnalyticsPreferences.storageKey) private var isEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.diagnostics_section", systemImage: "waveform.path.ecg", tokens: tokens)
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.diagnostics.title")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                    Text("settings.diagnostics.subtitle")
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
            }
            .tint(Color(hexToken: tokens.primary))
            .onChange(of: isEnabled) { _, newValue in
                if !newValue {
                    (Container.shared.analyticsTracking() as? BackendAnalyticsRecorder)?.discardQueued()
                }
            }
            .brandCard(tokens)
        }
    }
}

private struct ContentSyncSection: View {
    let tokens: ColorTokens
    @Environment(ContentSyncStatus.self) private var status

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.sync_section", systemImage: "arrow.triangle.2.circlepath", tokens: tokens)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color(hexToken: iconToken))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
                Spacer(minLength: 0)
            }
            .brandCard(tokens)
            .accessibilityElement(children: .combine)
        }
    }

    private var icon: String {
        switch status.state {
        case .never: "clock"
        case .syncing: "arrow.triangle.2.circlepath"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    // A failure is amber, not red: the app still works from its cached copy, and
    // colouring it as an error would overstate what the user is looking at.
    private var iconToken: String {
        if case .failed = status.state { return tokens.accent }
        return tokens.primary
    }

    private var title: LocalizedStringKey {
        switch status.state {
        case .never: "settings.sync.never"
        case .syncing: "settings.sync.in_progress"
        case .succeeded: "settings.sync.up_to_date"
        case .failed: "settings.sync.failed"
        }
    }

    private var detail: LocalizedStringKey {
        switch status.state {
        case .never:
            "settings.sync.never_detail"
        case .syncing:
            "settings.sync.in_progress_detail"
        case let .succeeded(at, updated):
            updated.isEmpty
                ? "settings.sync.checked_at \(Self.time.string(from: at))"
                : "settings.sync.updated_at \(updated.count) \(Self.time.string(from: at))"
        case let .failed(at, keys):
            "settings.sync.failed_detail \(keys.count) \(Self.time.string(from: at))"
        }
    }
}

private struct AppearanceSection: View {
    let tokens: ColorTokens
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.appearance_section", systemImage: "paintbrush.fill", tokens: tokens)
            Picker("settings.appearance_section", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.labelKey, systemImage: mode.systemImage).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .brandCard(tokens)
        }
    }
}

/// Language row. iOS keeps per-app language in the system Settings app (the
/// "Preferred Language" screen that appears once the app ships >1 localization),
/// so the native, Apple-sanctioned way to switch is to deep-link there rather
/// than build an in-app locale picker.
private struct LanguageSection: View {
    let tokens: ColorTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.language_section", systemImage: "globe", tokens: tokens)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.language.title")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color(hexToken: tokens.onSurface))
                        Text("settings.language.subtitle")
                            .font(.caption)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app.fill")
                        .foregroundStyle(Color(hexToken: tokens.primary))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .brandCard(tokens)
            .accessibilityHint(Text("settings.language.subtitle"))
        }
    }
}

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
