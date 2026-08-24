import BikeDomain
import Foundation
import MeasurementPresentation
import SettingsDomain

extension BatteryHealthViewModel {
    @MainActor
    static func preview() -> BatteryHealthViewModel {
        BatteryHealthViewModel(
            useCases: .init(
                startMonitoring: .init(repository: BatteryHealthPreviewRepository()),
                stopMonitoring: .init(repository: BatteryHealthPreviewRepository()),
                observeHealth: .init(repository: BatteryHealthPreviewRepository()),
                observeCaptures: .init(repository: BatteryHealthPreviewRepository()),
                observeSettings: .init(repository: BatteryHealthPreviewSettingsRepository()),
                prepareChargePowerControl: .init(repository: BatteryHealthPreviewRepository()),
                setChargePowerLimit: .init(repository: BatteryHealthPreviewRepository()),
                setChargeTarget: .init(repository: BatteryHealthPreviewRepository())
            ),
            mapper: .init(formatter: .preview()),
            makeMapper: { _ in .init(formatter: .preview()) },
            chargeControlLogStore: BatteryHealthChargeControlLogStore(),
            chargeControlStateUpdater: BatteryHealthChargeControlStateUpdater(
                normalizer: BatteryHealthChargeControlNormalizer()
            ),
            chargeControlTaskScheduler: BatteryHealthChargeControlTaskScheduler(),
            captureTimeFormatter: SystemTimeFormatter()
        )
    }
}

@MainActor
private extension BatteryHealthFormatter {
    static func preview() -> BatteryHealthFormatter {
        let locale = Locale.autoupdatingCurrent
        return BatteryHealthFormatter(
            locale: locale,
            measurementSystem: .metric
        )
    }
}

private actor BatteryHealthPreviewSettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func save(_: AppSettings) async {}
    func observe() async -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
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
