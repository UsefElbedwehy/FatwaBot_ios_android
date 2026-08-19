import UserNotifications

/// Notification tones, resolved from bundled audio when it exists.
///
/// iOS can only play a custom notification tone from a file inside the app
/// bundle (or `Library/Sounds`) — there is no API to pick a different system
/// tone. So a genuinely custom sound needs an audio asset; until one is added,
/// every case here degrades to the system default rather than going silent.
///
/// Requirements for the file, when it is supplied: CAF/AIFF/WAV, **30 seconds
/// or shorter** (iOS silently substitutes the default beyond that), and added
/// to the app target — not to a package, which the notification system cannot
/// read from.
enum NotificationSound {
    /// Filename to drop into the app bundle to give the adhan its own tone.
    static let adhanFileName = "adhan.caf"

    /// The adhan is the call to prayer itself; it should not sound like a
    /// generic reminder. Falls back to the default when no file is bundled.
    static var adhan: UNNotificationSound {
        guard Bundle.main.url(forResource: "adhan", withExtension: "caf") != nil else {
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName(adhanFileName))
    }
}
