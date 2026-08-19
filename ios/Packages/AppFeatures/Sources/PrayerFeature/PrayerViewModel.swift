import Foundation
import Observation
import PrayerKit

/// State machine for the Prayer surface (screen + Home hero share it).
/// Pure over injected dependencies; all effects owned here, never in views.
@MainActor
@Observable
public final class PrayerViewModel {
    public enum Status: Equatable {
        case needsLocation           // denied + no cache → manual city path
        case ready
    }

    public private(set) var status: Status = .ready
    public private(set) var location: UserLocation?
    public private(set) var today: PrayerDay?
    public private(set) var tomorrow: PrayerDay?
    public private(set) var nextPrayer: NextPrayerState?
    public private(set) var hijri: HijriDate?
    public private(set) var settings: PrayerSettings

    /// User's notification preferences (per-type toggles + offsets); editable
    /// from Settings and persisted via `notificationPreferenceStore`.
    public private(set) var notificationPreferences: PrayerNotificationPreferences

    private let engine: PrayerEngine
    private let locationProvider: LocationProviding
    private let scheduler: PrayerNotificationScheduling?
    private let notificationPreferenceStore: NotificationPreferenceStoring
    private let widgetStore: WidgetSnapshotStore?
    private let reloadWidgets: (@Sendable () -> Void)?
    private let liveActivity: PrayerLiveActivityManaging
    private let liveActivityPreference: LiveActivityPreferenceStoring
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        engine: PrayerEngine = PrayerEngine(),
        locationProvider: LocationProviding,
        scheduler: PrayerNotificationScheduling? = nil,
        notificationPreferenceStore: NotificationPreferenceStoring = UserDefaultsNotificationPreferenceStore(),
        widgetStore: WidgetSnapshotStore? = nil,
        reloadWidgets: (@Sendable () -> Void)? = nil,
        liveActivity: PrayerLiveActivityManaging = NoopPrayerLiveActivityManager(),
        liveActivityPreference: LiveActivityPreferenceStoring = UserDefaultsLiveActivityPreferenceStore(),
        settings: PrayerSettings = PrayerSettings(),
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.engine = engine
        self.locationProvider = locationProvider
        self.scheduler = scheduler
        self.notificationPreferenceStore = notificationPreferenceStore
        self.notificationPreferences = notificationPreferenceStore.load()
        self.widgetStore = widgetStore
        self.reloadWidgets = reloadWidgets
        self.liveActivity = liveActivity
        self.liveActivityPreference = liveActivityPreference
        self.settings = settings
        self.now = now
        self.calendar = calendar
        // Instant first paint from cache; resolve() refines asynchronously.
        // Widget snapshot write is skipped here (updateWidget: false) — it's a
        // disk write + WidgetKit IPC call, not needed to unblock first paint,
        // and start() re-applies with updateWidget: true moments later anyway.
        if let cached = locationProvider.cached() {
            apply(location: cached, updateWidget: false)
        }
    }

    public func start() async {
        switch await locationProvider.resolve() {
        case .resolved(let location):
            apply(location: location)
            await rescheduleNotifications()
        case .denied:
            if location == nil { status = .needsLocation }
        case .unknown:
            break
        }
    }

    /// Prayer time on a given day, for callers that schedule around prayers —
    /// currently the prayer-anchored wird reminders.
    ///
    /// Returns nil with no location, which is a real state on first launch: the
    /// wird planner treats that as "fall back to the clock time" rather than
    /// emitting nothing.
    public func prayerTime(dayOffset: Int, prayer: String) -> Date? {
        guard let location, let name = PrayerName(rawValue: prayer) else { return nil }
        let cal = locationCalendar(for: location)
        guard let day = cal.date(byAdding: .day, value: dayOffset, to: now()) else { return nil }
        let start = cal.dateComponents([.year, .month, .day], from: day)
        guard let timeline = try? engine.timeline(
            latitude: location.latitude, longitude: location.longitude,
            startDate: start, days: 1, settings: settings, calendar: cal
        ) else { return nil }
        return timeline.first?.times[name]
    }

    /// A **Gregorian** calendar anchored to the resolved location's timezone
    /// rather than the device's, for resolving which civil day/hour
    /// "today"/"now" means before handing it to `PrayerEngine`/Adhan.
    ///
    /// Two independent things go wrong without this, and both were found live:
    ///
    /// 1. **Timezone.** A manually selected city (or GPS resolving faster than
    ///    an automatic-timezone device catches up) in a different timezone
    ///    than the device computed and *displayed* prayer times using the
    ///    device's timezone — correct in absolute UTC terms, but shown as,
    ///    say, Fajr at 3 PM local device time.
    ///
    /// 2. **Calendar identifier.** `calendar` (injected as device `.current`)
    ///    is not guaranteed to be Gregorian — `ar_SA` and similar locales
    ///    default `Calendar.current` to Islamic Umm al-Qura unless a user
    ///    explicitly overrides it in Settings. Adhan has no concept of
    ///    calendar systems; it treats whatever `year`/`month`/`day` it's
    ///    given as Gregorian. Extracting "today" via an Islamic calendar and
    ///    handing e.g. `(1448, 3, 1)` to Adhan computes real, valid prayer
    ///    times — for Gregorian March 1st, year 1448 AD. Forcing `.gregorian`
    ///    here, always, regardless of what identifier `calendar` itself has,
    ///    is what Adhan's contract actually requires.
    private func locationCalendar(for location: UserLocation?) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location?.timeZone ?? calendar.timeZone
        return cal
    }

    /// The timezone prayer times should be displayed in — see `locationCalendar(for:)`.
    public var displayTimeZone: TimeZone { location?.timeZone ?? calendar.timeZone }

    /// Rebuilds the rolling notification window (docs/features/prayer.md triggers).
    /// How many days of prayer times to lay out for the notification schedule.
    ///
    /// Was 3, which silently capped the horizon: the planner had 48 slots but was
    /// only ever handed three days of times, so the budget work above could never
    /// reach past day three no matter how it allocated. Ten days is what 48 slots
    /// can actually carry once the schedule degrades to adhan-only beyond the
    /// full-fidelity window.
    private var notificationHorizonDays: Int { 10 }

    public func rescheduleNotifications() async {
        guard let scheduler, let location else { return }
        let cal = locationCalendar(for: location)
        let start = cal.dateComponents([.year, .month, .day], from: now())
        guard let timeline = try? engine.timeline(
            latitude: location.latitude, longitude: location.longitude,
            startDate: start, days: notificationHorizonDays, settings: settings, calendar: cal
        ) else { return }
        await scheduler.reschedule(timeline: timeline, preferences: notificationPreferences, now: now())
    }

    /// Current OS notification permission — for a Settings banner. Distinct
    /// from `rescheduleNotifications()` silently building a schedule nobody
    /// will see: a `.denied` user gets exactly the same "success" from every
    /// scheduler call as an authorized one, with nothing telling them why the
    /// call to prayer never arrives.
    public func notificationAuthorizationStatus() async -> NotificationAuthorization {
        guard let scheduler else { return .notDetermined }
        return await scheduler.authorizationStatus()
    }

    /// Persist edited notification preferences and rebuild the schedule.
    public func setNotificationPreferences(_ preferences: PrayerNotificationPreferences) {
        notificationPreferences = preferences
        notificationPreferenceStore.save(preferences)
        Task { await rescheduleNotifications() }
    }

    public func select(city: ManualCity, displayName: String) {
        (locationProvider as? SystemLocationProvider)?.setManualCity(city, displayName: displayName)
        apply(location: UserLocation(
            latitude: city.latitude, longitude: city.longitude,
            name: displayName, countryCode: city.countryCode, isManual: true,
            timeZone: city.timeZone
        ))
    }

    public func update(settings: PrayerSettings) {
        self.settings = settings
        if let location { apply(location: location) }
    }

    /// Recompute countdown state (call on timer tick / foreground).
    public func refreshNextPrayer() {
        guard let today, let tomorrow else { return }
        nextPrayer = PrayerEngine.nextPrayer(now: now(), today: today, tomorrow: tomorrow)
        syncLiveActivity()
    }

    /// Settings-screen entry point (ADR-0016): off by default, and disabling
    /// ends any running activity immediately rather than waiting for the next
    /// state transition to notice the preference changed.
    public func setLiveActivityEnabled(_ enabled: Bool) {
        liveActivityPreference.setEnabled(enabled)
        if enabled {
            syncLiveActivity()
        } else {
            Task { await liveActivity.end() }
        }
    }

    public func day(offset: Int) -> PrayerDay? {
        guard let location else { return nil }
        let cal = locationCalendar(for: location)
        let date = cal.date(byAdding: .day, value: offset, to: now())!
        let components = cal.dateComponents([.year, .month, .day], from: date)
        return try? engine.day(
            latitude: location.latitude, longitude: location.longitude,
            date: components, settings: settings
        )
    }

    private func apply(location: UserLocation, updateWidget: Bool = true) {
        self.location = location
        self.status = .ready
        let cal = locationCalendar(for: location)
        let currentDate = now()
        let todayComponents = cal.dateComponents([.year, .month, .day], from: currentDate)
        guard let days = try? engine.timeline(
            latitude: location.latitude, longitude: location.longitude,
            startDate: todayComponents, days: 2, settings: settings, calendar: cal
        ), days.count == 2 else { return }
        today = days[0]
        tomorrow = days[1]
        nextPrayer = PrayerEngine.nextPrayer(now: currentDate, today: days[0], tomorrow: days[1])
        hijri = HijriDate(from: currentDate, offsetDays: settings.hijriOffsetDays, timeZone: location.timeZone)
        if updateWidget {
            writeWidgetSnapshot(location: location, from: todayComponents, calendar: cal)
            syncLiveActivity()
        }
    }

    /// Starts/updates/ends the Live Activity to match the current next-prayer
    /// state (ADR-0016) — a no-op via NoopPrayerLiveActivityManager unless the
    /// app container wires a real ActivityKit-backed manager.
    private func syncLiveActivity() {
        guard liveActivityPreference.isEnabled() else {
            Task { await liveActivity.end() }
            return
        }
        guard let nextPrayer, let location else { return }
        Task { await liveActivity.start(locationName: location.name, prayerName: nextPrayer.next, prayerTime: nextPrayer.nextTime) }
    }

    /// Precomputes a 48h widget snapshot into the app-group store so widget
    /// processes render with zero network (docs/features/prayer.md).
    private func writeWidgetSnapshot(location: UserLocation, from startComponents: DateComponents, calendar: Calendar) {
        guard let widgetStore else { return }
        let currentDate = now()
        guard let widgetTimeline = try? engine.timeline(
            latitude: location.latitude, longitude: location.longitude,
            startDate: startComponents, days: 3, settings: settings, calendar: calendar
        ) else { return }
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: widgetTimeline,
            location: location.name,
            hijri: HijriDate(from: currentDate, offsetDays: settings.hijriOffsetDays, timeZone: location.timeZone),
            generatedAt: currentDate,
            timeZoneIdentifier: location.timeZone?.identifier
        )
        widgetStore.write(snapshot)
        reloadWidgets?()
    }
}
