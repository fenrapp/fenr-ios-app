@testable import BatteryHealth
import BikeDomain
import ChargeControl
import Foundation
import MeasurementPresentation
import VehicleSession

@MainActor
func makeBatteryHealthViewModel(
    repository: any BikeBatteryHealthRepository & BikeChargePowerControlRepository,
    monitoringState: VehicleBatteryHealthMonitoringState = .active
) -> BatteryHealthViewModel {
    BatteryHealthViewModel(
        useCases: .init(
            observeCaptures: .init(repository: repository)
        ),
        vehicleSession: FakeBatteryHealthVehicleSession(
            repository: repository,
            monitoringState: monitoringState
        ),
        mapper: .init(formatter: makeBatteryHealthFormatter()),
        makeMapper: { _ in .init(formatter: makeBatteryHealthFormatter()) },
        chargeControl: makeChargeControlSession(repository: repository),
        captureTimeFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
    )
}

@MainActor
func makeChargeControlSession(repository: any BikeChargePowerControlRepository) -> ChargeControlSession {
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
