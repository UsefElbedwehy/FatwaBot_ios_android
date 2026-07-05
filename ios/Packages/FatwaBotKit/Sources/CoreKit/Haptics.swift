/// Haptic feedback boundary shared by any feature that needs it (Tasbeeh,
/// Azkar, ...). Lives in CoreKit, not a feature module, so features never
/// depend on one another for it (ADR-0010: feature -> feature is forbidden).
public protocol HapticsProviding: Sendable {
    /// A light, frequent tap — e.g. one dhikr count.
    func tick()
    /// A distinct, less-frequent confirmation — e.g. reaching a target/count.
    func targetReached()
}

public struct NoopHaptics: HapticsProviding {
    public init() {}
    public func tick() {}
    public func targetReached() {}
}
