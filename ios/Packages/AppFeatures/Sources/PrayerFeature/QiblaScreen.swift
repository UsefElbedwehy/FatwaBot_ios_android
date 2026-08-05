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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(location: UserLocation, provider: HeadingProviding) {
        self.bearing = PrayerCalculator().qiblaBearing(
            latitude: location.latitude, longitude: location.longitude
        )
        self.provider = provider
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !provider.supportsHeading {
                    staticFallback
                } else {
                    compassCard
                    accuracyNotice
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .brandScreenBackground(tokens)
        .task {
            for await update in provider.headings() {
                if reduceMotion {
                    heading = update.heading
                    accuracy = update.accuracy
                } else {
                    withAnimation(.interactiveSpring) {
                        heading = update.heading
                        accuracy = update.accuracy
                    }
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

    /// The compass housed in an elevated circular card carrying the mihrab motif.
    private var compassCard: some View {
        VStack(spacing: 18) {
            compass
                .padding(28)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hexToken: tokens.surfaceElevated),
                                        Color(hexToken: tokens.primaryContainer).opacity(0.5),
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        // Faint mihrab motif oriented toward the qibla needle.
                        MihrabArchShape(archRatio: 0.6)
                            .fill(Color(hexToken: tokens.primary).opacity(0.05))
                            .frame(width: 150, height: 180)
                            .rotationEffect(.degrees(needleAngle))
                            .allowsHitTesting(false)
                    }
                )
                .overlay(
                    Circle()
                        .stroke(Color(hexToken: tokens.primary).opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color(hexToken: tokens.primary).opacity(0.12), radius: 18, x: 0, y: 10)

            bearingReadout
        }
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

    /// Prominent qibla bearing readout below the compass.
    private var bearingReadout: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(Int(bearing))°")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(hexToken: isAligned ? tokens.accent : tokens.primary))
                .contentTransition(.numericText())
            Text("qibla.compass_a11y")
                .font(.caption)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var accuracyNotice: some View {
        if accuracy < 0 {
            noticeCard(icon: "gyroscope", titleKey: "qibla.calibrating", tint: tokens.accent)
        } else if accuracy > 25 {
            noticeCard(icon: "exclamationmark.triangle", titleKey: "qibla.interference", tint: tokens.accent)
        }
    }

    /// Subtle branded notice card for calibration / interference states.
    private func noticeCard(icon: String, titleKey: LocalizedStringKey, tint: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hexToken: tint))
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            Spacer(minLength: 0)
        }
        .brandCard(tokens)
    }

    private var staticFallback: some View {
        VStack(spacing: 18) {
            BrandLogoBadge(tokens: tokens)
            Text("qibla.static_bearing \(Int(bearing))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .brandCard(tokens, padding: 24)
        .accessibilityElement(children: .combine)
    }
}
