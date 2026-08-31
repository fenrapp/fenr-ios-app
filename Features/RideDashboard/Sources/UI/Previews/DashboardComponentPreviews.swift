import DesignSystem
import SwiftUI

#if DEBUG
#Preview("Speed gauge") {
    DashboardSpeedometer(
        state: .init(
            valueText: "82",
            unit: "km/h",
            progress: 82.0 / 180.0,
            accessibilityLabel: "Speed 82 km/h"
        )
    )
    .frame(width: 620, height: 310)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Speed progress bar") {
    DashboardProgressBar(state: .speed(progress: 0.65))
        .frame(width: 844, height: 7)
        .background(Color.black)
}

#Preview("Energy progress bar") {
    VStack(spacing: DesignSpace.large) {
        DashboardProgressBar(state: .energy(
            regenerationProgress: 0.62,
            consumptionProgress: .zero,
            accessibilityLabel: "Regenerating 6.2 kW"
        ))
        DashboardProgressBar(state: .neutralEnergy)
        DashboardProgressBar(state: .energy(
            regenerationProgress: .zero,
            consumptionProgress: 0.72,
            accessibilityLabel: "Consuming 32.0 kW"
        ))
    }
    .frame(width: 844)
    .padding(.vertical)
    .background(Color.black)
}

#Preview("Battery panel") {
    VStack(alignment: .leading, spacing: DesignSpace.large) {
        DashboardBatteryPanel(
            state: previewBattery(percentage: 78, emphasis: .positive),
            showsEstimatedRange: true,
            estimatedRange: .init(
                valueText: "212",
                unitText: "km",
                accessibilityLabel: "Estimated range 212 kilometers"
            )
        )
        DashboardBatteryPanel(
            state: previewBattery(percentage: 78, emphasis: .positive),
            showsEstimatedRange: true
        )
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
        )
    ])
    .padding()
    .background(Color.black)
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
