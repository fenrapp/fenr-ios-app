import BikeDomain

public enum BikeEmulatorRepositoryFactory {
    public static func make(
        scenario: BikeEmulatorScenario = .charging,
        powerModePreset: BikeEmulatorPowerModePreset = .standard,
        activeMap: Int = 4
    ) -> BikeEmulatorRepository {
        BikeEmulatorRepository(
            scenario: scenario,
            powerModePreset: powerModePreset,
            activeMapNumber: activeMap,
            channels: BikeEmulatorChannels(
                telemetry: BikeEmulatorEventHub<BikeTelemetry>(replaysLatestValue: true),
                connection: BikeEmulatorEventHub<BikeConnection>(replaysLatestValue: true),
                debugEvent: BikeEmulatorEventHub<BikeDebugEvent>(replaysLatestValue: true),
                batteryHealth: BikeEmulatorEventHub<BikeBatteryHealth>(replaysLatestValue: true),
                capture: BikeEmulatorCaptureHub(),
                discoveredBikes: BikeEmulatorEventHub<[DiscoveredBike]>(replaysLatestValue: true)
            ),
            powerCalculator: BikePowerTelemetryCalculator()
        )
    }
}

struct BikeEmulatorChannels {
    let telemetry: BikeEmulatorEventHub<BikeTelemetry>
    let connection: BikeEmulatorEventHub<BikeConnection>
    let debugEvent: BikeEmulatorEventHub<BikeDebugEvent>
    let batteryHealth: BikeEmulatorEventHub<BikeBatteryHealth>
    let capture: BikeEmulatorCaptureHub
    let discoveredBikes: BikeEmulatorEventHub<[DiscoveredBike]>
}
