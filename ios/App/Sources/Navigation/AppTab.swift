import SwiftUI

/// The four top-level destinations (design direction §3).
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case worship
    case journey
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .home: "tabs.home"
        case .worship: "tabs.worship"
        case .journey: "tabs.journey"
        case .settings: "tabs.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .worship: "hands.and.sparkles.fill"
        case .journey: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape.fill"
        }
    }
}
