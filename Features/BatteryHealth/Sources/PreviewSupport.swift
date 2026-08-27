import BikeDomain
import ChargeControl
import Foundation
import MeasurementPresentation
import SettingsDomain
import VehicleSession

enum BatteryHealthPreviewFactory {
    @MainActor
    static func makeViewModel() -> BatteryHealthViewModel {
        let formatter = makeFormatter()
        let repository = BatteryHealthPreviewRepository()
        return BatteryHealthViewModel(
            useCases: .init(
                observeCaptures: .init(repository: repository)
            ),
            vehicleSession: BatteryHealthPreviewVehicleSession(),
            mapper: .init(formatter: formatter),
            makeMapper: { _ in .init(formatter: makeFormatter()) },
            chargeControl: ChargeControlSession(
                useCases: .init(
                    prepare: .init(repository: repository),
                    setPowerLimit: .init(repository: repository),
                    setTarget: .init(repository: repository)
                ),
                logger: ChargeControlLogStore(),
                stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
                taskScheduler: ChargeControlTaskScheduler()
            ),
            captureTimeFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
        )
    }

    @MainActor
    private static func makeFormatter() -> BatteryHealthFormatter {
        let locale = Locale.autoupdatingCurrent
        return BatteryHealthFormatter(
            locale: locale,
            measurementMapper: VehicleMeasurementMapper(measurementSystem: .metric),
            measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
        )
    }
}

private actor BatteryHealthPreviewVehicleSession: VehicleSessionService {
    func observe() -> AsyncStream<VehicleSessionSnapshot> {
        AsyncStream { continuation in
            continuation.yield(.init(
                batteryHealth: .init(
                    stateOfCharge: .known(percent: 76),
                    stateOfHealth: .known(percent: 94),
                    dcBusVoltage: .known(volts: 394.8),
                    chargeState: .charging,
                    lastUpdated: Date()
                ),
                batteryHealthMonitoringState: .active
            ))
        }
    }

    func start() {}
    func stop() {}
    func refreshBikeStatus() {}
    func calibrateDeviceMotion() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}
}

private struct BatteryHealthPreviewRepository: BikeBatteryHealthRepository {
    func startBatteryHealthMonitoring() async throws {}
    func stopBatteryHealthMonitoring() async {}

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        AsyncStream { continuation in
            continuation.yield(.init(
                stateOfCharge: .known(percent: 76),
                stateOfHealth: .known(percent: 94),
                dcBusVoltage: .known(volts: 394.8),
                chargeState: .charging,
                lastUpdated: Date()
            ))
            continuation.finish()
        }
    }

    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        AsyncStream { continuation in
            continuation.yield(.init(
                dataset: .temperatures,
                byteCount: 12,
                hex: "00 00 00 00",
                date: Date()
            ))
            continuation.finish()
        }
    }
}
