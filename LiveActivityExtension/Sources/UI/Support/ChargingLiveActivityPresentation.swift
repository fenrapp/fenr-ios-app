import DesignSystem
import SwiftUI

enum ChargingLiveActivityPresentation {
    static let widgetURL = URL(string: "fenr://charging")

    static func tint(for phase: ChargingLiveActivityPhase) -> SwiftUI.Color {
        switch phase {
        case .charging:
            DesignColor.informational
        case .balancing:
            DesignColor.positive
        case .complete:
            DesignColor.positive
        case .stale:
            DesignColor.warning
        case .connectionLost:
            DesignColor.critical
        }
    }
}
