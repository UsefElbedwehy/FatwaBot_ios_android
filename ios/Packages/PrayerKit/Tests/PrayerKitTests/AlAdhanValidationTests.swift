import XCTest
@testable import PrayerKit

/// Authority validation (closes the M0 corpus TODO: "spot-validate against
/// official Umm al-Qura timetables"). The golden corpus only proves our port
/// matches adhan-js; this proves our on-device Umm al-Qura output matches the
/// **official AlAdhan Umm al-Qura** timings (method=4, Makkah university) to the
/// minute, for real Saudi cities. Fixture is committed — the test runs offline.
final class AlAdhanValidationTests: XCTestCase {
    struct Fixture: Decodable {
        let toleranceMinutes: Int
        let entries: [Entry]
        enum CodingKeys: String, CodingKey {
            case toleranceMinutes = "tolerance_minutes"
            case entries
        }
    }
    struct Entry: Decodable {
        let city: String
        let latitude: Double
        let longitude: Double
        let timezone: String
        let date: String
        let method: String
        let madhab: String
        let timesLocal: [String: String]
        enum CodingKeys: String, CodingKey {
            case city, latitude, longitude, timezone, date, method, madhab
            case timesLocal = "times_local"
        }
    }

    static func fixtureURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() } // → repo root
        return url.appendingPathComponent("content/test-fixtures/prayer-times/aladhan-umm-al-qura.json")
    }

    private func localMinutes(_ date: Date, timeZone: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        // Round to the nearest minute to match AlAdhan's minute-rounded output.
        return (c.hour! * 60) + c.minute! + ((c.second ?? 0) >= 30 ? 1 : 0)
    }

    private func parseHHMM(_ s: String) -> Int {
        let p = s.split(separator: ":").compactMap { Int($0) }
        return p[0] * 60 + p[1]
    }

    func testOnDeviceUmmAlQuraMatchesAlAdhanAuthority() throws {
        let data = try Data(contentsOf: Self.fixtureURL())
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        XCTAssertGreaterThanOrEqual(fixture.entries.count, 12, "fixture should cover several cities × dates")

        let engine = PrayerEngine()
        var failures: [String] = []

        for entry in fixture.entries {
            let tz = TimeZone(identifier: entry.timezone)!
            let parts = entry.date.split(separator: "-").compactMap { Int($0) }
            let settings = PrayerSettings(method: entry.method, madhab: entry.madhab)
            let day = try engine.day(
                latitude: entry.latitude,
                longitude: entry.longitude,
                date: DateComponents(year: parts[0], month: parts[1], day: parts[2]),
                settings: settings
            )
            for (key, name): (String, PrayerName) in [
                ("fajr", .fajr), ("sunrise", .sunrise), ("dhuhr", .dhuhr),
                ("asr", .asr), ("maghrib", .maghrib), ("isha", .isha),
            ] {
                let ours = localMinutes(day.time(name), timeZone: tz)
                let theirs = parseHHMM(entry.timesLocal[key]!)
                let diff = abs(ours - theirs)
                if diff > fixture.toleranceMinutes {
                    failures.append("\(entry.city) \(entry.date) \(key): ours=\(ours/60):\(ours%60) authority=\(entry.timesLocal[key]!) Δ=\(diff)min")
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, "Umm al-Qura diverges from the AlAdhan authority:\n" + failures.joined(separator: "\n"))
    }
}
