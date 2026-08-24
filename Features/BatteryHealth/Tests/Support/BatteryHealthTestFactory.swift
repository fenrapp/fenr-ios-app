@testable import BatteryHealth
import BikeDomain
import Foundation
import MeasurementPresentation

@MainActor
func makeBatteryHealthViewModel(repository: any BikeBatteryHealthRepository) -> BatteryHealthViewModel {
    BatteryHealthViewModel(
        useCases: .init(
            startMonitoring: .init(repository: repository),
            stopMonitoring: .init(repository: repository),
            observeHealth: .init(repository: repository),
            observeCaptures: .init(repository: repository),
            observeSettings: .init(repository: FakeAppSettingsRepository()),
            prepareChargePowerControl: .init(repository: repository),
            setChargePowerLimit: .init(repository: repository),
            setChargeTarget: .init(repository: repository)
        ),
        mapper: .init(formatter: makeBatteryHealthFormatter()),
        makeMapper: { _ in .init(formatter: makeBatteryHealthFormatter()) },
        chargeControlLogStore: BatteryHealthChargeControlLogStore(),
        chargeControlStateUpdater: BatteryHealthChargeControlStateUpdater(
            normalizer: BatteryHealthChargeControlNormalizer()
        ),
        chargeControlTaskScheduler: BatteryHealthChargeControlTaskScheduler(),
        captureTimeFormatter: SystemTimeFormatter()
    )
}

@MainActor
func makeBatteryHealthFormatter(locale: Locale = .init(identifier: "en_US")) -> BatteryHealthFormatter {
    return BatteryHealthFormatter(
        locale: locale,
        measurementSystem: locale.measurementSystem
    )
}
