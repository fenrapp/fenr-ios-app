import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import VehicleSession

@MainActor
func makeFixture(
    timing: RideDashboardTiming = .live,
    initialConnectionStabilityPeriod: Duration = .zero,
    reconnectionNoticeDelay: Duration = .seconds(5)
) -> RideDashboardViewModelTestFixture {
    let vehicleSession = RideDashboardVehicleSession()
    return .init(
        viewModel: RideDashboardViewModel(
            mapper: RideDashboardMapperFactory.makeRideMapper(
                locale: Locale(identifier: "en_GB")
            ),
            cardLayoutMapper: DashboardCardLayoutMapper(),
            vehicleSession: vehicleSession,
            timing: timing,
            continuityPolicy: RideDashboardContinuityPolicy(),
            initialConnectionStabilityPeriod: initialConnectionStabilityPeriod,
            reconnectionNoticeDelay: reconnectionNoticeDelay
        ),
        vehicleSession: vehicleSession
    )
}

func ridingSnapshot(
    speed: Double,
    temperatureDisplayMode: DashboardTemperatureDisplayMode = .off,
    isCanonicalTelemetryAvailable: Bool = true
) -> VehicleSessionSnapshot {
    .init(
        telemetry: .init(
            batteryLevel: .known(percent: 64),
            speed: .known(kmh: speed, kmhX10: Int((speed * 10).rounded())),
            statusFlags: .init(isOn: true, isInGear: true),
            lastUpdated: .init(timeIntervalSinceReferenceDate: 1)
        ),
        connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
        settings: .init(
            dashboardProgressBarMode: .speed,
            dashboardBatteryIndicatorMode: .estimatedRange,
            dashboardTemperatureDisplayMode: temperatureDisplayMode,
            measurementSystem: .metric
        ),
        resolvedSpeedKilometersPerHour: speed,
        hasReceivedSettings: true,
        hasReceivedProfile: true,
        isCanonicalTelemetryAvailable: isCanonicalTelemetryAvailable
    )
}

func powerModeSnapshot(
    mode: Int,
    includesConfiguration: Bool
) -> VehicleSessionSnapshot {
    let configuration = BikePowerModeConfiguration(
        mapIndex: mode - 1,
        horsepower: 60,
        regenerativeBrakingPercent: 40,
        powerTractionPercent: 20,
        brakingTractionPercent: 20
    )
    return .init(
        telemetry: .init(
            batteryLevel: .known(percent: 64),
            mode: .index(mode),
            speed: .known(kmh: 20, kmhX10: 200),
            statusFlags: .init(isOn: true, isInGear: true),
            powerModeConfigurations: includesConfiguration ? [mode - 1: configuration] : [:],
            lastUpdated: .init(timeIntervalSinceReferenceDate: 1)
        ),
        connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
        resolvedSpeedKilometersPerHour: 20,
        hasReceivedSettings: true,
        hasReceivedProfile: true
    )
}

struct RideDashboardViewModelTestFixture {
    let viewModel: RideDashboardViewModel
    let vehicleSession: RideDashboardVehicleSession
}
