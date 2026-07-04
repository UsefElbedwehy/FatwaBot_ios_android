import CoreLocation
import DesignSystemKit
import PrayerKit
import SwiftUI

public protocol HeadingProviding: Sendable {
    /// Magnetic heading stream in degrees + accuracy (negative = invalid).
    func headings() -> AsyncStream<(heading: Double, accuracy: Double)>
    var supportsHeading: Bool { get }
}

#if os(iOS)
public final class SystemHeadingProvider: NSObject, HeadingProviding, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<(heading: Double, accuracy: Double)>.Continuation?

    public var supportsHeading: Bool { CLLocationManager.headingAvailable() }

    public func headings() -> AsyncStream<(heading: Double, accuracy: Double)> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.manager.delegate = self
            self.manager.startUpdatingHeading()
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.manager.stopUpdatingHeading()
                }
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading needs location; fall back to magnetic when unavailable.
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        continuation?.yield((heading: heading, accuracy: newHeading.headingAccuracy))
    }
}
#else
/// Non-iOS test builds: no sensor support; QiblaScreen shows the static bearing.
public struct SystemHeadingProvider: HeadingProviding {
    public init() {}
    public var supportsHeading: Bool { false }
    public func headings() -> AsyncStream<(heading: Double, accuracy: Double)> {
        AsyncStream { $0.finish() }
    }
}
#endif

public struct QiblaScreen: View {
    private let bearing: Double
    private let provider: HeadingProviding
    @State private var heading: Double = 0
    @State private var accuracy: Double = -1
    @Environment(\.colorScheme) private var colorScheme

    public init(location: UserLocation, provider: HeadingProviding) {
        self.bearing = PrayerCalculator().qiblaBearing(
            latitude: location.latitude, longitude: location.longitude
        )
        self.provider = provider
    }

    public var body: some View {
        VStack(spacing: 24) {
            if !provider.supportsHeading {
                staticFallback
            } else {
                compass
                accuracyIndicator
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hexToken: tokens.surface))
        .task {
            for await update in provider.headings() {
                withAnimation(.interactiveSpring) {
                    heading = update.heading
                    accuracy = update.accuracy
                }
            }
        }
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    /// Angle the needle must point on screen: qibla bearing relative to device heading.
    var needleAngle: Double { bearing - heading }

    private var isAligned: Bool {
        let delta = abs((needleAngle.truncatingRemainder(dividingBy: 360) + 540)
            .truncatingRemainder(dividingBy: 360) - 180)
        return (180 - delta) < 5 || delta < 5
    }

    private var compass: some View {
        ZStack {
            Circle()
                .stroke(Color(hexToken: tokens.outline), lineWidth: 2)
                .frame(width: 260, height: 260)
            ForEach(["N", "E", "S", "W"], id: \.self) { point in
                let index = ["N", "E", "S", "W"].firstIndex(of: point)!
                Text(point)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    .offset(y: -145)
                    .rotationEffect(.degrees(Double(index) * 90 - heading))
            }
            Image(systemName: "location.north.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(hexToken: isAligned ? tokens.accent : tokens.primary))
                .rotationEffect(.degrees(needleAngle))
                .shadow(radius: isAligned ? 8 : 0)
        }
        .sensoryFeedback(.success, trigger: isAligned) { !$0 && $1 }
        .accessibilityLabel(Text("qibla.compass_a11y"))
        .accessibilityValue(Text(verbatim: "\(Int(bearing))°"))
    }

    private var accuracyIndicator: some View {
        Group {
            if accuracy < 0 {
                Label { Text("qibla.calibrating") } icon: { Image(systemName: "gyroscope") }
            } else if accuracy > 25 {
                Label { Text("qibla.interference") } icon: { Image(systemName: "exclamationmark.triangle") }
            } else {
                Text(verbatim: "\(Int(bearing))°")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
    }

    private var staticFallback: some View {
        VStack(spacing: 12) {
            Image(systemName: "safari")
                .font(.system(size: 48))
                .foregroundStyle(Color(hexToken: tokens.primary))
            Text("qibla.static_bearing \(Int(bearing))")
                .font(.title3)
        }
    }
}
