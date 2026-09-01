import DesignSystem
import SwiftUI

enum BikeLiveActivityPresentation {
    static let widgetURL = URL(string: "fenr://dashboard")

    static func tint(for phase: BikeLiveActivityPhase) -> SwiftUI.Color {
        switch phase {
        case .charging:
            DesignColor.informational
        case .balancing:
            DesignColor.positive
        case .complete:
            DesignColor.positive
        case .riding:
            DesignColor.accent
        case .neutral:
            DesignColor.secondaryText
        case .crawl:
            DesignColor.warning
        case .fault:
            DesignColor.critical
        case .reconnecting:
            DesignColor.warning
        case .stale:
            DesignColor.warning
        case .connectionLost:
            DesignColor.critical
        }
    }
}
