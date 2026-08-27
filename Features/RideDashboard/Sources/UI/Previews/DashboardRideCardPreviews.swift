import DesignSystem
import Foundation
import SwiftUI

#if DEBUG
#Preview("Current trip card") {
    DashboardCurrentTripCard(
        state: .init(
            durationText: "00:42:18",
            statusText: "IN PROGRESS",
            distance: .init(
                label: "DISTANCE",
                valueText: "32.4",
                unit: "km",
                systemImage: "location"
            ),
            averageSpeed: .init(
                label: "AVERAGE",
                valueText: "46",
                unit: "km/h",
                systemImage: "speedometer"
            ),
            maximumSpeed: .init(
                label: "MAX SPEED",
                valueText: "91",
                unit: "km/h",
                systemImage: "arrow.up.right"
            ),
            speedSourceIndicator: .init(
                text: "GPS+",
                systemImage: "arrow.triangle.branch"
            ),
            isActive: true,
            accessibilityLabel: "Current trip preview"
        ),
        freezesDurationUpdates: false,
        togglePause: {},
        reset: {}
    )
    .dashboardCardPreviewCanvas()
}

#Preview("Ride statistics card") {
    DashboardTripStatisticsCard(state: .init(
        statusText: "42 SAVED TRIPS",
        totalDistance: .init(label: "TOTAL DISTANCE", valueText: "1,284.6", unit: "km"),
        totalDuration: .init(label: "RIDE TIME", valueText: "38:24"),
        averageSpeed: .init(label: "AVERAGE", valueText: "41", unit: "km/h"),
        maximumSpeed: .init(label: "MAX SPEED", valueText: "137", unit: "km/h"),
        accessibilityLabel: "Ride statistics preview"
    ))
    .dashboardCardPreviewCanvas()
}

#Preview("Efficiency live card") {
    DashboardEfficiencyLiveCard(state: .init(
        valueText: "72",
        status: .calculated,
        usedEnergyText: "1.2 kWh",
        recoveredEnergyText: "180 Wh",
        powerPoints: previewPowerPoints
    ))
    .dashboardCardPreviewCanvas()
}

#Preview("Efficiency trend card") {
    DashboardEfficiencyTrendCard(state: .init(
        valueText: "72",
        status: .calculated,
        trendPoints: previewTrendPoints,
        hasConfirmedVehicle: true
    ))
    .dashboardCardPreviewCanvas()
}

private let previewPowerPoints: [DashboardEfficiencyViewData.PowerPoint] = {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)
    return stride(from: -60, through: 0, by: 5).map { offset in
        .init(
            date: now.addingTimeInterval(TimeInterval(offset)),
            kilowatts: sin(Double(offset) / 8) * 4
        )
    }
}()

private let previewTrendPoints: [DashboardEfficiencyViewData.TrendPoint] = {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)
    return [76, 71, 74, 69, 72].enumerated().map { index, efficiency in
        .init(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index)") ?? UUID(),
            date: now.addingTimeInterval(TimeInterval(index * 3_600)),
            efficiency: Double(efficiency)
        )
    }
}()

private extension View {
    func dashboardCardPreviewCanvas() -> some View {
        frame(width: 430, height: 390)
            .background(DesignColor.surface)
            .preferredColorScheme(.dark)
    }
}
#endif
