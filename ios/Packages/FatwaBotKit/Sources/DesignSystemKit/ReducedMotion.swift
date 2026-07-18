import SwiftUI

/// Applies `animation` only when the system's Reduce Motion accessibility
/// setting is off; otherwise the value change is silent (no animation at
/// all, matching the pattern already used by OnboardingScreen). Centralizing
/// this here means every `MotionTokens`-backed animation across the app gets
/// Reduce Motion support for free instead of each screen re-deriving it.
private struct ReducedMotionAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

public extension View {
    /// Reduce-Motion-aware replacement for `.animation(_:value:)`.
    func motionAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(ReducedMotionAnimation(animation: animation, value: value))
    }
}
