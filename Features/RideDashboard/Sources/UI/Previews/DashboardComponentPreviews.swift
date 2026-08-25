import DesignSystem
import SwiftUI

#if DEBUG
#Preview("Speed gauge") {
    DashboardSpeedometer(
        state: .init(
            value: 82,
            unit: "km/h",
            progress: 82.0 / 180.0,
            emphasis: .positive,
            accessibilityLabel: "Speed 82 km/h"
        ),
        reduceMotion: false
    )
    .frame(width: 620, height: 310)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Charging gauge") {
    DashboardChargingGauge(
        state: .init(
            batteryPercent: 82,
            targetPercent: 100,
            estimatedTimeRemaining: "32 min",
            isBalancingAtFullCharge: false
        ),
        reduceMotion: false
    )
    .frame(width: 620, height: 310)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Battery panel") {
    VStack(alignment: .leading, spacing: DesignSpace.large) {
        DashboardBatteryPanel(percentage: 78, compact: false)
        DashboardBatteryPanel(percentage: 18, compact: true)
        DashboardBatteryPanel(percentage: nil, compact: false)
    }
    .frame(width: 240)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Gear states") {
    HStack(spacing: DesignSpace.extraLarge) {
        DashboardGearPanel(state: .init(display: .text("N"), isActive: true, accessibilityLabel: "Gear neutral"))
        DashboardGearPanel(state: .init(display: .text("3"), isActive: true, accessibilityLabel: "Gear 3"))
        DashboardGearPanel(state: .init(display: .crawlForward, isActive: true, accessibilityLabel: "Crawl forward"))
        DashboardGearPanel(state: .init(display: .crawlReverse, isActive: true, accessibilityLabel: "Crawl reverse"))
    }
    .padding()
    .background(DesignColor.surface)
}

#Preview("Indicator rail") {
    DashboardIndicatorRail(indicators: [
        .init(
            id: "highBeam",
            symbolName: "headlight.high.beam",
            accessibilityLabel: "High beam",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .informational
        ),
        .init(
            id: "leftTurn",
            symbolName: "arrow.left",
            accessibilityLabel: "Left turn",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .positive
        ),
        .init(
            id: "brake",
            symbolName: "hand.raised.fill",
            accessibilityLabel: "Brake",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .warning
        ),
        .init(
            id: "fault",
            symbolName: "exclamationmark.triangle.fill",
            accessibilityLabel: "Fault",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .critical
        )
    ])
    .frame(width: 620, height: 48)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Ride metrics") {
    RideDashboardMetricsColumn(
        batteryPercent: 78,
        odometer: .init(valueText: "180.0", unitText: "km", animationValue: 180),
        compact: false
    )
    .frame(width: 240, height: 280)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Charging metrics") {
    ChargingDashboardMetricsColumn(
        viewState: .init(
            maximumPower: .init(valueText: "6.2", unitText: "kW", animationValue: 6.2),
            reportedCurrent: .init(valueText: "13.6", unitText: "A", animationValue: 13.6),
            batteryTemperature: .init(valueText: "24", unitText: "°C", animationValue: 24)
        ),
        compact: false
    )
    .frame(width: 240, height: 280)
    .padding()
    .background(DesignColor.surface)
}
#endif
