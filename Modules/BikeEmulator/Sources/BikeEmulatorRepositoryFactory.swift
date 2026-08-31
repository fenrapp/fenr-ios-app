import AsyncSupport
import BikeDomain

public enum BikeEmulatorRepositoryFactory {
    public static func make(
        scenario: BikeEmulatorScenario = .charging,
        powerModePreset: BikeEmulatorPowerModePreset = .standard,
        activeMap: Int = 4
    ) -> BikeEmulatorRepository {
        make(
            scenario: scenario,
            powerModePreset: powerModePreset,
            activeMap: activeMap,
            runtime: .live
        )
    }

    static func make(
        scenario: BikeEmulatorScenario,
        powerModePreset: BikeEmulatorPowerModePreset,
        activeMap: Int,
        runtime: BikeEmulatorRuntime
    ) -> BikeEmulatorRepository {
        BikeEmulatorRepository(
            scenario: scenario,
            powerModePreset: powerModePreset,
            activeMapNumber: activeMap,
            channels: BikeEmulatorChannels(
                telemetry: makeStateEventHub(),
                connection: makeStateEventHub(),
                imu: makeStateEventHub(replaysLatestValue: false),
                debugEvent: AsyncEventHub(
                    bufferingPolicy: .bufferingNewest(Buffering.debugEventLimit),
                    replaysLatestValue: true
                ),
                batteryHealth: makeStateEventHub(),
                capture: BikeEmulatorCaptureHub(),
                discoveredBikes: makeStateEventHub()
            ),
            powerCalculator: BikePowerTelemetryCalculator(),
            runtime: runtime
        )
    }

    private static func makeStateEventHub<Value: Sendable>(
        replaysLatestValue: Bool = true
    ) -> AsyncEventHub<Value> {
        AsyncEventHub(
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
    let telemetry: AsyncEventHub<BikeTelemetry>
    let connection: AsyncEventHub<BikeConnection>
    let imu: AsyncEventHub<BikeIMUSample>
    let debugEvent: AsyncEventHub<BikeDebugEvent>
    let batteryHealth: AsyncEventHub<BikeBatteryHealth>
    let capture: BikeEmulatorCaptureHub
    let discoveredBikes: AsyncEventHub<[DiscoveredBike]>
}
