import BikeDomain
import SettingsDomain
import VehicleSession

struct RideDashboardMappingInput: Equatable {
    struct Configuration: Equatable {
        let measurementSystem: MeasurementSystem
        let vin: String?
    }

    let configuration: Configuration
    let telemetry: BikeTelemetry
    let connection: BikeConnection
    let speedKilometersPerHour: Double?
    let speedSource: SpeedSource
    let progressBarMode: DashboardProgressBarMode
    let progressBarThickness: DashboardProgressBarThickness
    let batteryIndicatorMode: DashboardBatteryIndicatorMode
    let temperatureDisplayMode: DashboardTemperatureDisplayMode
    let isGPSAvailable: Bool
    let powerModeNames: [Int: PowerModeName]

    init(snapshot: VehicleSessionSnapshot) {
        configuration = .init(measurementSystem: snapshot.settings.measurementSystem, vin: snapshot.profile?.vin)
        telemetry = snapshot.telemetry
        connection = snapshot.connection
        speedKilometersPerHour = snapshot.resolvedSpeedKilometersPerHour
        speedSource = snapshot.speedSource
        progressBarMode = snapshot.settings.dashboardProgressBarMode
        progressBarThickness = snapshot.settings.dashboardProgressBarThickness
        batteryIndicatorMode = snapshot.settings.dashboardBatteryIndicatorMode
        temperatureDisplayMode = snapshot.settings.dashboardTemperatureDisplayMode
        isGPSAvailable = snapshot.isGPSAvailable
        powerModeNames = snapshot.settings.powerModeNames(forVIN: snapshot.profile?.vin)
    }

    func map(
        using mapper: RideDashboardMapper, measurementMapper: RideDashboardMeasurementMapper
    ) -> RideDashboardViewState {
        mapper.map(
            telemetry: telemetry, connection: connection, speedKilometersPerHour: speedKilometersPerHour,
            speedSource: speedSource, progressBarMode: progressBarMode, progressBarThickness: progressBarThickness,
            batteryIndicatorMode: batteryIndicatorMode,
            temperatureDisplayMode: temperatureDisplayMode, measurementSystem: configuration.measurementSystem,
            isGPSAvailable: isGPSAvailable, powerModeNames: powerModeNames, using: measurementMapper
        )
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.configuration == rhs.configuration
            && lhs.connection.state == rhs.connection.state
            && lhs.speedKilometersPerHour == rhs.speedKilometersPerHour
            && lhs.speedSource == rhs.speedSource
            && lhs.progressBarMode == rhs.progressBarMode
            && lhs.progressBarThickness == rhs.progressBarThickness
            && lhs.batteryIndicatorMode == rhs.batteryIndicatorMode
            && lhs.temperatureDisplayMode == rhs.temperatureDisplayMode
            && lhs.isGPSAvailable == rhs.isGPSAvailable
            && lhs.powerModeNames == rhs.powerModeNames
            && sameTelemetryPresentation(lhs.telemetry, rhs.telemetry)
    }

    private static func sameTelemetryPresentation(_ lhs: BikeTelemetry, _ rhs: BikeTelemetry) -> Bool {
        (lhs.speed.kmh != nil) == (rhs.speed.kmh != nil)
            && lhs.batteryLevel.percent == rhs.batteryLevel.percent
            && lhs.odometer.kilometers == rhs.odometer.kilometers
            && lhs.runState == rhs.runState
            && lhs.mode == rhs.mode
            && lhs.statusFlags.isChargerConnected == rhs.statusFlags.isChargerConnected
            && lhs.statusFlags.indicatorState == rhs.statusFlags.indicatorState
            && lhs.statusFlags.isBrakeActive == rhs.statusFlags.isBrakeActive
            && lhs.statusFlags.isFaultActive == rhs.statusFlags.isFaultActive
            && lhs.activePowerModeConfiguration == rhs.activePowerModeConfiguration
            && lhs.detectedPowerTier == rhs.detectedPowerTier
            && lhs.powerTelemetry.electricalPowerWatts == rhs.powerTelemetry.electricalPowerWatts
            && lhs.powerTelemetry.starkMotorPowerHorsepower == rhs.powerTelemetry.starkMotorPowerHorsepower
            && lhs.batteryTelemetry.positiveBMS?.temperatureCelsius
                == rhs.batteryTelemetry.positiveBMS?.temperatureCelsius
            && lhs.batteryTelemetry.negativeBMS?.temperatureCelsius
                == rhs.batteryTelemetry.negativeBMS?.temperatureCelsius
            && lhs.inverterTemperaturesCelsius == rhs.inverterTemperaturesCelsius
    }
}
