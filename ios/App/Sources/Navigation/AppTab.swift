import SwiftUI

/// The four top-level destinations (design direction §3).
enum AppTab: String, CaseIterable, Identifiable {
    case worship
    case home
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .home: "tabs.home"
        case .worship: "tabs.worship"
        case .settings: "tabs.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .worship: "square.grid.2x2.fill"
        case .settings: "gearshape.fill"
        }
    }
}
