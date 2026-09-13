import DesignSystem
import SwiftUI

enum WatchBatteryStyle {
    static func tint(for emphasis: WatchDashboardViewState.BatteryEmphasis) -> Color {
        switch emphasis {
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        case .unavailable: DesignColor.inactive
        }
    }
}
