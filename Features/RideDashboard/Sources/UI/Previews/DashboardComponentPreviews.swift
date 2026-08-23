import DesignSystem
import SwiftUI

#if DEBUG
#Preview("Speed gauge") {
    DashboardGauge(
        mode: .speed(
            speed: .init(value: 82, unit: "km/h"),
            maximum: .init(value: 180, unit: "km/h")
        ),
        reduceMotion: false
    )
    .frame(width: 620, height: 310)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Charging gauge") {
    DashboardGauge(
        mode: .charging(
            percentage: 82,
            targetPercentage: 100,
            estimatedTimeRemaining: "32 min"
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
        DashboardGearPanel(display: .text("N"), tint: DesignColor.positive)
        DashboardGearPanel(display: .text("3"), tint: DesignColor.positive)
        DashboardGearPanel(display: .crawlForward, tint: DesignColor.positive)
        DashboardGearPanel(display: .crawlReverse, tint: DesignColor.positive)
    }
    .padding()
    .background(DesignColor.surface)
}

#Preview("Indicator rail") {
    DashboardIndicatorRail(
        isHighBeamOn: true,
        isLeftBlinkerOn: true,
        isBrakeActive: true,
        isRightBlinkerOn: false,
        isFaultActive: true
    )
    .frame(width: 620, height: 48)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Ride metrics") {
    RideDashboardMetricsColumn(
        batteryPercent: 78,
        odometer: .init(value: 180, unit: "km"),
        compact: false
    )
    .frame(width: 240, height: 280)
    .padding()
    .background(DesignColor.surface)
}

#Preview("Charging metrics") {
    ChargingDashboardMetricsColumn(
        viewState: .init(
            maximumPower: .init(value: 6.2, unit: "kW"),
            reportedCurrent: .init(value: 13.6, unit: "A"),
            batteryTemperature: .init(value: 24, unit: "°C")
        ),
        compact: false
    )
    .frame(width: 240, height: 280)
    .padding()
    .background(DesignColor.surface)
}
#endif
