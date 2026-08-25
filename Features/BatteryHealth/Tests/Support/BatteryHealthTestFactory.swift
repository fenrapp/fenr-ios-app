@testable import BatteryHealth
import BikeDomain
import ChargeControl
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
            observeSettings: .init(repository: FakeAppSettingsRepository())
        ),
        mapper: .init(formatter: makeBatteryHealthFormatter()),
        makeMapper: { _ in .init(formatter: makeBatteryHealthFormatter()) },
        chargeControl: makeChargeControlSession(repository: repository),
        captureTimeFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
    )
}

@MainActor
func makeChargeControlSession(repository: any BikeBatteryHealthRepository) -> ChargeControlSession {
    ChargeControlSession(
        useCases: .init(
            prepare: .init(repository: repository),
            setPowerLimit: .init(repository: repository),
            setTarget: .init(repository: repository)
        ),
        logger: ChargeControlLogStore(),
        stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
        taskScheduler: ChargeControlTaskScheduler()
    )
}

@MainActor
func makeBatteryHealthFormatter(locale: Locale = .init(identifier: "en_US")) -> BatteryHealthFormatter {
    return BatteryHealthFormatter(
        locale: locale,
        measurementMapper: VehicleMeasurementMapper(measurementSystem: locale.measurementSystem),
        measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
    )
}
