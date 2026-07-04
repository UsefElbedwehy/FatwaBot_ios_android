#if canImport(SwiftUI)
import SwiftUI

extension Color {
    /// Builds a Color from a "#RRGGBB" token value. Falls back to clear on
    /// malformed input — token validation happens upstream in ColorTokens.
    public init(hexToken: String) {
        var value: UInt64 = 0
        let hex = String(hexToken.dropFirst())
        guard hexToken.hasPrefix("#"), Scanner(string: hex).scanHexInt64(&value), hex.count == 6 else {
            self = .clear
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
#endif
