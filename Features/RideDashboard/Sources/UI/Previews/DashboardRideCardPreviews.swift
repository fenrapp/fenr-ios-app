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

#Preview("Range live card") {
    DashboardRangeLiveCard(state: previewRangeState)
        .dashboardCardPreviewCanvas()
}

#Preview("Battery trip card") {
    DashboardBatteryTripCard(state: previewRangeState)
        .dashboardCardPreviewCanvas()
}

#Preview("System health healthy") {
    DashboardSystemHealthCard(state: previewSystemHealthHealthyState)
        .dashboardCardPreviewCanvas()
}

#Preview("System health cell anomaly") {
    DashboardSystemHealthCellsCard(state: previewSystemHealthAnomalyState)
        .dashboardCardPreviewCanvas()
}

#Preview("System health balancing") {
    DashboardSystemHealthCellsCard(state: previewSystemHealthBalancingState)
        .dashboardCardPreviewCanvas()
}

#Preview("System health thermal") {
    DashboardSystemHealthThermalCard(state: previewSystemHealthHealthyState)
        .dashboardCardPreviewCanvas()
}

#Preview("System health scanning") {
    DashboardSystemHealthCard(state: .init())
        .dashboardCardPreviewCanvas()
}

#Preview("System health unavailable") {
    DashboardSystemHealthCard(state: .init(
        status: .unavailable,
        statusText: "UNAVAILABLE",
        statusDetail: "BMS DATA UNAVAILABLE"
    ))
    .dashboardCardPreviewCanvas()
}

#Preview("Ride dynamics lean") {
    DashboardLeanCard(state: previewDynamicsState, reduceMotion: false, calibrate: {})
        .dashboardCardPreviewCanvas()
}

#Preview("Ride dynamics pitch") {
    DashboardPitchCard(state: previewDynamicsState, reduceMotion: false, calibrate: {})
        .dashboardCardPreviewCanvas()
}

#Preview("Ride dynamics calibration") {
    DashboardLeanCard(state: previewCalibrationRequiredState, reduceMotion: false, calibrate: {})
        .dashboardCardPreviewCanvas()
}

#Preview("Ride dynamics unavailable") {
    DashboardPitchCard(state: .init(), reduceMotion: false, calibrate: {})
        .dashboardCardPreviewCanvas()
}

#Preview("Ride dynamics course") {
    DashboardCourseCard(state: previewDynamicsState, reduceMotion: false)
        .dashboardCardPreviewCanvas()
}

#Preview("Ride dynamics course without location") {
    DashboardCourseCard(state: previewCompassWithoutLocationState, reduceMotion: false)
        .dashboardCardPreviewCanvas()
}

#Preview("Ride dynamics course unavailable") {
    DashboardCourseCard(state: .init(), reduceMotion: false)
        .dashboardCardPreviewCanvas()
}

private let previewPowerPoints: [DashboardEfficiencyViewData.PowerPoint] = {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)
    return stride(from: -60, through: 0, by: 5).map { offset in
        let signedKilowatts = sin(Double(offset) / 8) * 4
        return .init(
            date: now.addingTimeInterval(TimeInterval(offset)),
            usedKilowatts: max(signedKilowatts, .zero),
            regenKilowatts: max(-signedKilowatts, .zero)
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

private let previewRangeState = DashboardRangeViewData(
    rangeText: "64",
    status: .stable,
    typicalRangeText: "71",
    currentRangeText: "58",
    batteryText: "66%",
    remainingEnergyText: "4.5 kWh",
    typicalEfficiency: 72,
    consumptionPoints: [68, 84, 63, -18, 91, 74].enumerated().map { index, efficiency in
        .init(id: UUID(), distance: Double(index) * 1.5, efficiency: Double(efficiency))
    },
    batteryPoints: [72, 71, 70, 68, 67, 66].enumerated().map { index, percentage in
        .init(id: UUID(), distance: Double(index) * 1.5, percentage: Double(percentage))
    },
    peakDischargeText: "18.4 kW",
    peakRegenerationText: "6.2 kW"
)

private let previewSystemHealthHealthyState = makePreviewSystemHealthState()

private let previewSystemHealthAnomalyState = makePreviewSystemHealthState(
    criticalCellPosition: 18,
    status: .critical,
    statusText: "CRITICAL",
    statusDetail: "1 CELL CRITICAL"
)

private let previewSystemHealthBalancingState = makePreviewSystemHealthState(
    balancingCellPositions: [12, 57],
    statusDetail: "CELL BALANCING ACTIVE"
)

private func makePreviewSystemHealthState(
    criticalCellPosition: Int? = nil,
    balancingCellPositions: Set<Int> = [],
    status: DashboardSystemHealthViewData.Status = .healthy,
    statusText: String = "OK",
    statusDetail: String = "ALL SYSTEMS NORMAL"
) -> DashboardSystemHealthViewData {
    let cells = (1 ... 100).map { position in
        let isCritical = position == criticalCellPosition
        let variation = Double((position * 7) % 9)
        let voltageText = (3.89 + variation * 0.001)
            .formatted(.number.precision(.fractionLength(4))) + " V"
        return DashboardSystemHealthViewData.Cell(
            position: position,
            voltageText: isCritical ? "2.8500 V" : voltageText,
            deviationText: isCritical ? "−1,042 mV" : "\(Int(variation) - 4) mV",
            condition: isCritical ? .critical : .normal,
            isBalancing: balancingCellPositions.contains(position)
        )
    }
    return .init(
        status: status,
        statusText: statusText,
        statusDetail: statusDetail,
        stateOfHealthText: "94%",
        stateOfHealthProgress: 0.94,
        cellDeltaText: criticalCellPosition == nil ? "8 mV" : "1,048 mV",
        dcBusVoltageText: "394.8 V",
        batteryTemperatureText: "29°C",
        inverterTemperatureText: "44°C",
        criticalCellCount: criticalCellPosition == nil ? 0 : 1,
        balancingCellCount: balancingCellPositions.count,
        cells: cells,
        minimumCellText: criticalCellPosition.map { "#\($0) · 2.8500 V" } ?? "#1 · 3.8900 V",
        maximumCellText: "#99 · 3.8980 V",
        batteryThermalRange: .init(
            minimumCelsius: 24,
            averageCelsius: 27,
            maximumCelsius: 29,
            minimumText: "24°C",
            averageText: "27°C",
            maximumText: "29°C"
        ),
        inverterThermalRange: .init(
            minimumCelsius: 39,
            averageCelsius: 42,
            maximumCelsius: 44,
            minimumText: "39°C",
            averageText: "42°C",
            maximumText: "44°C"
        )
    )
}

private let previewDynamicsState = DashboardRideDynamicsViewData(
    status: .live,
    leanDegrees: -18,
    leanText: "18°",
    leanDirectionText: "LEFT",
    maximumLeftLeanText: "34°",
    maximumRightLeanText: "29°",
    pitchDegrees: 6,
    pitchText: "6°",
    pitchDirectionText: "UP",
    maximumUphillPitchText: "14°",
    maximumDownhillPitchText: "11°",
    headingDegrees: 336,
    isHeadingAvailable: true,
    headingText: "336°",
    cardinalDirectionText: "NNW",
    headingSourceText: "GPS",
    altitudeText: "1,045 m",
    latitudeText: "40°25′35″ N",
    longitudeText: "3°42′14″ W",
    canCalibrate: true
)

private let previewCompassWithoutLocationState = DashboardRideDynamicsViewData(
    status: .live,
    headingDegrees: 74,
    isHeadingAvailable: true,
    headingText: "74°",
    cardinalDirectionText: "ENE",
    headingSourceText: "COMPASS",
    altitudeText: nil,
    canCalibrate: true
)

private let previewCalibrationRequiredState = DashboardRideDynamicsViewData(
    status: .calibrating,
    maximumLeftLeanText: "34°",
    maximumRightLeanText: "29°",
    canCalibrate: true
)

private extension View {
    func dashboardCardPreviewCanvas() -> some View {
        frame(width: 430, height: 390)
            .background(DesignColor.surface)
            .preferredColorScheme(.dark)
    }
}
#endif
