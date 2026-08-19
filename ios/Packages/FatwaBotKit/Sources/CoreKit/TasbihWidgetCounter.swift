import Foundation

/// The counter behind the interactive العداد widget.
///
/// ## Why this is its own state and not the in-app tasbeeh session
/// The app's tasbeeh feature persists *completed sessions* through
/// `TasbeehHistoryStoring` — a record of finished dhikr, not a live tally. A
/// widget tap is a single increment with no session, no chosen dhikr and no
/// completion, so writing it there would either fabricate sessions or corrupt
/// the history the Journey screen reads.
///
/// The two counters are therefore separate today, which is a real product gap
/// worth deciding on deliberately rather than resolving by accident here: a user
/// may well expect the widget and the in-app counter to be the same number.
///
/// ## Why the day is part of the state
/// A tally with no date silently accumulates across days — someone who counted
/// 100 yesterday opens their phone to a widget claiming 100 today. Resetting on
/// read is what makes the number mean "today".
public struct TasbihWidgetCounter: Codable, Equatable, Sendable {
    public private(set) var count: Int
    /// Start of the local day this tally belongs to.
    public private(set) var day: Date

    public init(count: Int = 0, day: Date = Calendar.current.startOfDay(for: Date())) {
        self.count = count
        self.day = day
    }

    /// The tally as of `date`, zeroed if it belongs to an earlier day.
    public func current(on date: Date = Date()) -> Int {
        Calendar.current.isDate(day, inSameDayAs: date) ? count : 0
    }

    public func incremented(on date: Date = Date()) -> TasbihWidgetCounter {
        TasbihWidgetCounter(
            count: current(on: date) + 1,
            day: Calendar.current.startOfDay(for: date)
        )
    }

    public func reset(on date: Date = Date()) -> TasbihWidgetCounter {
        TasbihWidgetCounter(count: 0, day: Calendar.current.startOfDay(for: date))
    }
}

/// Shared read/write via the app-group container.
public struct TasbihWidgetCounterStore: Sendable {
    private let fileURL: URL

    public init(appGroupContainer: URL) {
        self.fileURL = appGroupContainer.appendingPathComponent("tasbih-widget-counter.json")
    }

    public func read() -> TasbihWidgetCounter {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let counter = try? decoder.decode(TasbihWidgetCounter.self, from: data)
        else { return TasbihWidgetCounter() }
        return counter
    }

    public func write(_ counter: TasbihWidgetCounter) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(counter) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
