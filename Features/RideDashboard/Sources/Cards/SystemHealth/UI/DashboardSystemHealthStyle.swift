import DesignSystem
import SwiftUI

enum DashboardSystemHealthStyle {
    static func color(for status: DashboardSystemHealthViewData.Status) -> Color {
        switch status {
        case .scanning, .unavailable: DesignColor.secondaryText
        case .healthy: DesignColor.positive
        case .attention: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }
}
