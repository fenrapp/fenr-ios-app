import AsyncSupport
import BikeDomain
import Foundation

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

    public static func make(configuration: BikeEmulatorConfiguration) -> BikeEmulatorRepository {
        make(
            scenario: configuration.initialState.scenario,
            powerModePreset: configuration.initialState.powerModePreset,
            activeMap: configuration.initialState.activeMap,
            runtime: .live,
            configuration: configuration
        )
    }

    static func make(
        scenario: BikeEmulatorScenario,
        powerModePreset: BikeEmulatorPowerModePreset,
        activeMap: Int,
        runtime: BikeEmulatorRuntime,
        configuration: BikeEmulatorConfiguration? = nil
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
            runtime: runtime,
            configuration: configuration ?? BikeEmulatorConfiguration(
                vin: BikeEmulatorIdentity.vin,
                peripheralIdentifier: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
                initialState: .init(scenario: scenario, powerModePreset: powerModePreset, activeMap: activeMap),
                isDemo: false,
                persist: { _ in }
            )
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
