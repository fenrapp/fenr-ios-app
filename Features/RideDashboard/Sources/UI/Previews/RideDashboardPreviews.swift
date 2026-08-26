import SwiftUI

#if DEBUG
private enum DashboardPreviewConstants {
    static let landscapeWidth: CGFloat = 844
    static let landscapeHeight: CGFloat = 390
}

#Preview("Dashboard portrait") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(
                state: .init(
                    speedometer: previewSpeedometer(value: 20),
                    battery: previewBattery(percentage: 78, emphasis: .positive),
                    gear: previewGear("2"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(highBeam: true, brake: true)
                )
            ),
            currentTripViewModel: previewCurrentTripViewModel(),
            tripStatisticsViewModel: previewTripStatisticsViewModel(),
            chargingViewModel: previewChargingViewModel(),
            onDiagnostics: {}
        )
    }
}

#Preview("Dashboard landscape") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(
                state: .init(
                    speedometer: previewSpeedometer(value: 142),
                    battery: previewBattery(percentage: 34, emphasis: .warning),
                    gear: previewGear("3"),
                    powerMode: previewPowerMode(horsepower: "40", regen: "30"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(rightTurn: true)
                )
            ),
            currentTripViewModel: previewCurrentTripViewModel(),
            tripStatisticsViewModel: previewTripStatisticsViewModel(),
            chargingViewModel: previewChargingViewModel(),
            onDiagnostics: {}
        )
    }
    .frame(width: DashboardPreviewConstants.landscapeWidth, height: DashboardPreviewConstants.landscapeHeight)
    .preferredColorScheme(.dark)
}

#Preview("Dashboard low battery") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(
                state: .init(
                    speedometer: previewSpeedometer(value: 96),
                    battery: previewBattery(percentage: 12, emphasis: .critical),
                    gear: previewGear("4"),
                    powerMode: previewPowerMode(horsepower: "50", regen: "40"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(fault: true)
                )
            ),
            currentTripViewModel: previewCurrentTripViewModel(),
            tripStatisticsViewModel: previewTripStatisticsViewModel(),
            chargingViewModel: previewChargingViewModel(),
            onDiagnostics: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dashboard disconnected") {
    NavigationStack {
        RideDashboardView(
            viewModel: RideDashboardPreviewFactory.makeViewModel(state: .init()),
            currentTripViewModel: previewCurrentTripViewModel(),
            tripStatisticsViewModel: previewTripStatisticsViewModel(),
            chargingViewModel: previewChargingViewModel(),
            onDiagnostics: {}
        )
    }
}

#Preview("Dashboard charging") {
    RideDashboardView(
        viewModel: RideDashboardPreviewFactory.makeViewModel(
            state: .init(
                gear: previewGear("N"),
                centerMode: .charging,
                connectionDetail: "Live telemetry active",
                hasTelemetry: true,
                indicators: previewIndicators()
            )
        ),
        currentTripViewModel: previewCurrentTripViewModel(),
        tripStatisticsViewModel: previewTripStatisticsViewModel(),
        chargingViewModel: previewChargingViewModel(
            state: .init(
                batteryPercent: 68,
                targetPercent: 90,
                estimatedTimeRemaining: "45 min",
                readout: .init(
                    title: "ETA: 45 min",
                    subtitle: "TARGET 90%",
                    accessibilityLabel: "Charging 68 percent. Target 90 percent"
                )
            )
        ),
        onDiagnostics: {}
    )
    .frame(width: DashboardPreviewConstants.landscapeWidth, height: DashboardPreviewConstants.landscapeHeight)
}

@MainActor
private func previewChargingViewModel(
    state: ChargingDashboardViewState = .init()
) -> ChargingDashboardViewModel {
    ChargingDashboardPreviewFactory.makeViewModel(state: state)
}

@MainActor
private func previewCurrentTripViewModel() -> CurrentTripCardViewModel {
    CurrentTripCardPreviewFactory.makeViewModel(
        state: .init(
            durationText: "00:42:18",
            statusText: "IN PROGRESS",
            distance: .init(label: "DISTANCE", valueText: "32.4", unit: "km", systemImage: "location"),
            averageSpeed: .init(label: "AVERAGE", valueText: "46", unit: "km/h", systemImage: "speedometer"),
            maximumSpeed: .init(label: "MAX SPEED", valueText: "91", unit: "km/h", systemImage: "arrow.up.right"),
            isActive: true,
            accessibilityLabel: "Current trip preview"
        )
    )
}

@MainActor
private func previewTripStatisticsViewModel() -> TripStatisticsCardViewModel {
    TripStatisticsCardPreviewFactory.makeViewModel(
        state: .init(
            statusText: "42 SAVED TRIPS",
            totalDistance: .init(label: "TOTAL DISTANCE", valueText: "1,284.6", unit: "km"),
            totalDuration: .init(label: "RIDE TIME", valueText: "38:24"),
            averageSpeed: .init(label: "AVERAGE", valueText: "41", unit: "km/h"),
            maximumSpeed: .init(label: "MAX SPEED", valueText: "137", unit: "km/h"),
            accessibilityLabel: "Ride statistics preview"
        )
    )
}

private func previewSpeedometer(value: Double) -> DashboardSpeedometerViewData {
    .init(
        valueText: value.rounded().formatted(.number.precision(.fractionLength(0))),
        unit: "km/h",
        progress: value / 180,
        accessibilityLabel: "Speed \(Int(value)) km/h"
    )
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

private func previewGear(_ text: String) -> DashboardGearViewData {
    .init(display: .text(text), isActive: true, accessibilityLabel: "Gear \(text)")
}

private func previewPowerMode(horsepower: String, regen: String) -> DashboardPowerModeViewData {
    .init(
        horsepower: horsepower,
        regenerativeBraking: regen,
        isVisible: true
    )
}

private func previewIndicators(
    highBeam: Bool = false,
    brake: Bool = false,
    rightTurn: Bool = false,
    fault: Bool = false
) -> [DashboardIndicatorViewData] {
    [
        previewIndicator("highBeam", "headlight.high.beam", "High beam", highBeam, .informational),
        previewIndicator("leftTurn", "arrow.left", "Left turn", false, .warning),
        previewIndicator("brake", "exclamationmark.circle.fill", "Brake", brake, .critical),
        previewIndicator("rightTurn", "arrow.right", "Right turn", rightTurn, .warning),
        previewIndicator("fault", "exclamationmark.triangle.fill", "Fault", fault, .critical)
    ]
}

private func previewIndicator(
    _ id: String,
    _ symbolName: String,
    _ label: String,
    _ isActive: Bool,
    _ emphasis: DashboardIndicatorEmphasis
) -> DashboardIndicatorViewData {
    .init(
        id: id,
        symbolName: symbolName,
        accessibilityLabel: label,
        accessibilityValue: isActive ? "On" : "Off",
        isActive: isActive,
        emphasis: emphasis
    )
}
#endif
