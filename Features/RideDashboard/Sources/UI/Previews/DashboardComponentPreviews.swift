import DesignSystem
import SwiftUI

#if DEBUG
#Preview("Speed gauge") {
    DashboardSpeedometer(
        state: .init(
            value: 82,
            valueText: "82",
            unit: "km/h",
            progress: 82.0 / 180.0,
            emphasis: .positive,
            accessibilityLabel: "Speed 82 km/h"
        )
    )
    .frame(width: 620, height: 310)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Speed progress bar") {
    DashboardSpeedProgressBar(progress: 0.65)
        .frame(width: 844, height: 3)
        .background(Color.black)
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
        DashboardBatteryPanel(state: previewBattery(percentage: 78, emphasis: .positive))
        DashboardBatteryPanel(state: previewBattery(percentage: 28, emphasis: .warning))
        DashboardBatteryPanel(state: previewBattery(percentage: 8, emphasis: .critical))
        DashboardBatteryPanel(state: .init())
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

#Preview("Power mode summary") {
    VStack(spacing: DesignSpace.large) {
        DashboardPowerModeSummary(state: .init(
            horsepower: "40",
            regenerativeBraking: "30",
            isVisible: true
        ))
        DashboardPowerModeSummary(state: .init(
            horsepower: "80",
            regenerativeBraking: "50",
            powerTraction: "35",
            showsTractionControl: true,
            isVisible: true
        ))
    }
    .padding()
    .background(DesignColor.surface)
}

#Preview("Ambient lighting") {
    DashboardAmbientLighting(indicators: [
        .init(
            id: "leftTurn",
            symbolName: "arrow.left",
            accessibilityLabel: "Left turn",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .warning
        ),
        .init(
            id: "rightTurn",
            symbolName: "arrow.right",
            accessibilityLabel: "Right turn",
            accessibilityValue: "Off",
            isActive: false,
            emphasis: .warning
        )
    ])
    .frame(width: 844, height: 390)
    .background(Color.black)
}

#Preview("Indicator status") {
    DashboardIndicatorStatus(indicators: [
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
            emphasis: .warning
        ),
        .init(
            id: "brake",
            symbolName: "exclamationmark.circle.fill",
            accessibilityLabel: "Brake",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .critical
        )
    ])
    .padding()
    .background(Color.black)
}

#Preview("Ride metrics") {
    RideDashboardMetricsColumn(
        battery: previewBattery(percentage: 78, emphasis: .positive),
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

private func previewBattery(
    percentage: Int,
    emphasis: RideDashboardViewState.Battery.Emphasis
) -> RideDashboardViewState.Battery {
    .init(
        percentageText: "\(percentage)%",
        progress: Double(percentage) / 100,
        emphasis: emphasis,
        accessibilityLabel: "Battery \(percentage) percent"
    )
}
#endif
