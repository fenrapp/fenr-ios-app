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
                telemetry: makeStateEventHub(),
                connection: makeStateEventHub(),
                imu: makeStateEventHub(replaysLatestValue: false),
                debugEvent: BikeEmulatorEventHub(
                    bufferingPolicy: .bufferingNewest(Buffering.debugEventLimit),
                    replaysLatestValue: true
                ),
                batteryHealth: makeStateEventHub(),
                capture: BikeEmulatorCaptureHub(),
                discoveredBikes: makeStateEventHub()
            ),
            powerCalculator: BikePowerTelemetryCalculator()
        )
    }

    private static func makeStateEventHub<Value: Sendable>(
        replaysLatestValue: Bool = true
    ) -> BikeEmulatorEventHub<Value> {
        BikeEmulatorEventHub(
            bufferingPolicy: .bufferingNewest(Buffering.stateEventLimit),
            replaysLatestValue: replaysLatestValue
        )
    }

    private enum Buffering {
        static let stateEventLimit = 1
        static let debugEventLimit = 128
    }
}

struct BikeEmulatorChannels {
    let telemetry: BikeEmulatorEventHub<BikeTelemetry>
    let connection: BikeEmulatorEventHub<BikeConnection>
    let imu: BikeEmulatorEventHub<BikeIMUSample>
    let debugEvent: BikeEmulatorEventHub<BikeDebugEvent>
    let batteryHealth: BikeEmulatorEventHub<BikeBatteryHealth>
    let capture: BikeEmulatorCaptureHub
    let discoveredBikes: BikeEmulatorEventHub<[DiscoveredBike]>
}
