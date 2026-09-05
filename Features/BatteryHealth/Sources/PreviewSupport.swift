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
        let analyzer = BatteryHealthAnalyzer()
        let captureFormatter = BatteryHealthCaptureFormatter(
            dateFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
        )
        return BatteryHealthViewModel(
            useCases: .init(
                observeCaptures: .init(repository: repository)
            ),
            vehicleSession: BatteryHealthPreviewVehicleSession(),
            mapper: .init(
                formatter: formatter,
                analyzer: analyzer,
                captureFormatter: captureFormatter,
                now: Date.init
            ),
            makeMapper: { _ in
                .init(
                    formatter: makeFormatter(),
                    analyzer: analyzer,
                    captureFormatter: captureFormatter,
                    now: Date.init
                )
            },
            chargeControl: ChargeControlSession(
                useCases: .init(
                    prepare: .init(repository: repository),
                    setPowerLimit: .init(repository: repository),
                    setTarget: .init(repository: repository)
                ),
                logger: ChargeControlLogStore(isRecording: { true }),
                stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
                taskScheduler: ChargeControlTaskScheduler()
            ),
            captureFormatter: captureFormatter
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
    func zeroBikeAttitude() {}
    func setBatteryHealthMonitoringRequired(_: Bool, consumerID _: UUID) {}
}

private struct BatteryHealthPreviewRepository: BikeBatteryHealthRepository,
    BikeChargePowerControlRepository {
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
