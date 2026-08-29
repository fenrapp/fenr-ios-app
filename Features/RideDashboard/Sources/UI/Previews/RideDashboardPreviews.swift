import SettingsDomain
import SwiftUI

#if DEBUG
private enum DashboardPreviewConstants {
    static let landscapeWidth: CGFloat = 844
    static let landscapeHeight: CGFloat = 390
}

#Preview("Dashboard portrait") {
    NavigationStack {
        RideDashboardView(
            feature: previewFeature(
                dashboardState: .init(
                    speedometer: previewSpeedometer(value: 20),
                    battery: previewBattery(percentage: 78, emphasis: .positive),
                    gear: previewGear("2"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(highBeam: true, brake: true)
                )
            ),
            onDiagnostics: {}
        )
    }
}

#Preview("Dashboard landscape") {
    NavigationStack {
        RideDashboardView(
            feature: previewFeature(
                dashboardState: .init(
                    speedometer: previewSpeedometer(value: 142),
                    progressBar: .energy(
                        regenerationProgress: .zero,
                        consumptionProgress: 0.72,
                        accessibilityLabel: "Consuming 32.0 kW"
                    ),
                    battery: previewBattery(percentage: 34, emphasis: .warning),
                    temperatureSummary: .init(
                        batteryTemperatureText: "26°C",
                        inverterTemperatureText: "48°C"
                    ),
                    gear: previewGear("3"),
                    powerMode: previewPowerMode(horsepower: "40", regen: "30"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(rightTurn: true)
                )
            ),
            onDiagnostics: {}
        )
    }
    .frame(width: DashboardPreviewConstants.landscapeWidth, height: DashboardPreviewConstants.landscapeHeight)
    .preferredColorScheme(.dark)
}

#Preview("Dashboard low battery") {
    NavigationStack {
        RideDashboardView(
            feature: previewFeature(
                dashboardState: .init(
                    speedometer: previewSpeedometer(value: 96),
                    progressBar: .energy(
                        regenerationProgress: 0.62,
                        consumptionProgress: .zero,
                        accessibilityLabel: "Regenerating 6.2 kW"
                    ),
                    battery: previewBattery(percentage: 12, emphasis: .critical),
                    gear: previewGear("4"),
                    powerMode: previewPowerMode(horsepower: "50", regen: "40"),
                    connectionDetail: "Live telemetry active",
                    hasTelemetry: true,
                    indicators: previewIndicators(fault: true)
                )
            ),
            onDiagnostics: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Dashboard disconnected") {
    NavigationStack {
        RideDashboardView(
            feature: previewFeature(dashboardState: .init()),
            onDiagnostics: {}
        )
    }
}

#Preview("Dashboard charging") {
    RideDashboardView(
        feature: previewFeature(
            dashboardState: .init(
                gear: previewGear("N"),
                centerMode: .charging,
                connectionDetail: "Live telemetry active",
                hasTelemetry: true,
                indicators: previewIndicators()
            ),
            chargingState: .init(
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
private func previewFeature(
    dashboardState: RideDashboardViewState,
    chargingState: ChargingDashboardViewState = .init()
) -> RideDashboardFeatureModel {
    RideDashboardFeatureModel(
        dashboardViewModel: RideDashboardPreviewFactory.makeViewModel(state: dashboardState),
        deviceBatteryViewModel: previewDeviceBatteryViewModel(),
        currentTripViewModel: previewCurrentTripViewModel(),
        tripStatisticsViewModel: previewTripStatisticsViewModel(),
        efficiencyViewModel: previewEfficiencyViewModel(),
        rangeViewModel: previewRangeViewModel(),
        systemHealthViewModel: SystemHealthCardPreviewFactory.makeViewModel(
            state: previewDashboardSystemHealthState
        ),
        dynamicsViewModel: RideDynamicsCardPreviewFactory.makeViewModel(
            state: .init(
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
        ),
        chargingViewModel: previewChargingViewModel(state: chargingState),
        bikeLockViewModel: BikeLockCardPreviewFactory.makeViewModel()
    )
}

@MainActor
private func previewDeviceBatteryViewModel() -> DashboardDeviceBatteryViewModel {
    let settingsRepository = PreviewDashboardDeviceBatterySettingsRepository()
    let viewModel = DashboardDeviceBatteryViewModel(
        monitor: PreviewDashboardDeviceBatteryMonitor(),
        loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
        saveSettings: SaveAppSettingsUseCase(repository: settingsRepository)
    )
    viewModel.setPreviewState(.init(
        percentageText: "64%",
        systemImage: "battery.75percent",
        emphasis: .normal,
        accessibilityLabel: "iPhone battery 64 percent"
    ))
    return viewModel
}

private actor PreviewDashboardDeviceBatterySettingsRepository: AppSettingsRepository {
    private var settings = AppSettings()

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func observe() -> AsyncStream<AppSettings> { AsyncStream { $0.finish() } }
}

private final class PreviewDashboardDeviceBatteryMonitor: DashboardDeviceBatteryMonitoring {
    @MainActor func start() {}
    @MainActor func stop() {}

    @MainActor
    func observe() -> AsyncStream<DashboardDeviceBatterySnapshot> {
        AsyncStream { continuation in
            continuation.yield(.init(level: 0.64, isCharging: false))
        }
    }
}

private let previewDashboardSystemHealthState = DashboardSystemHealthViewData(
    status: .healthy,
    statusText: "OK",
    statusDetail: "ALL SYSTEMS NORMAL",
    stateOfHealthText: "94%",
    stateOfHealthProgress: 0.94,
    cellDeltaText: "8 mV",
    dcBusVoltageText: "394.8 V",
    batteryTemperatureText: "29°C",
    inverterTemperatureText: "44°C"
)

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

@MainActor
private func previewEfficiencyViewModel() -> EfficiencyCardViewModel {
    EfficiencyCardPreviewFactory.makeViewModel(
        state: DashboardEfficiencyViewData(
            valueText: "72",
            status: .calculated,
            usedEnergyText: "1.2 kWh",
            recoveredEnergyText: "180 Wh"
        )
    )
}

@MainActor
private func previewRangeViewModel() -> RangeCardViewModel {
    RangeCardPreviewFactory.makeViewModel(
        state: .init(
            rangeText: "64",
            summary: .init(
                valueText: "64",
                unitText: "km",
                accessibilityLabel: "Estimated range 64 kilometers"
            ),
            status: .stable,
            typicalRangeText: "71",
            currentRangeText: "58",
            batteryText: "66%",
            remainingEnergyText: "4.5 kWh"
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
