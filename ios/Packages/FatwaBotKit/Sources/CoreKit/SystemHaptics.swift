#if os(iOS)
import UIKit

public struct SystemHaptics: HapticsProviding {
    public init() {}

    public func tick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    public func targetReached() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
#else
public struct SystemHaptics: HapticsProviding {
    public init() {}
    public func tick() {}
    public func targetReached() {}
}
#endif
