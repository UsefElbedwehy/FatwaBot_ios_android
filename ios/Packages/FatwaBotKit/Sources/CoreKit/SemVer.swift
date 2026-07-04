import Foundation

/// Dotted-numeric version comparison for rollout gates ("1.2.10" ≥ "1.2.9").
/// Non-numeric fragments compare as 0; missing components as 0.
public enum SemVer {
    public static func isVersion(_ version: String, atLeast minimum: String) -> Bool {
        let lhs = components(version)
        let rhs = components(minimum)
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return true
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
