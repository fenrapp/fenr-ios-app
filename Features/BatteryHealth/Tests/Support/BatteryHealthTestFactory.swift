@testable import BatteryHealth
import BikeDomain
import ChargeControl
import Foundation
import MeasurementPresentation
import VehicleSession

@MainActor
func makeBatteryHealthViewModel(
    repository: any BikeBatteryHealthRepository & BikeChargePowerControlRepository,
    monitoringState: VehicleBatteryHealthMonitoringState = .active,
    vehicleSession: (any VehicleSessionService)? = nil
) -> BatteryHealthViewModel {
    BatteryHealthViewModel(
        useCases: .init(
            observeCaptures: .init(repository: repository)
        ),
        vehicleSession: vehicleSession ?? FakeBatteryHealthVehicleSession(
                repository: repository,
                monitoringState: monitoringState
            ),
        mapper: makeBatteryHealthMapper(),
        makeMapper: { _ in makeBatteryHealthMapper() },
        chargeControl: makeChargeControlSession(repository: repository),
        captureFormatter: .init(
            dateFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
        )
    )
}

@MainActor
func makeBatteryHealthMapper(
    now: @escaping @Sendable () -> Date = Date.init
) -> BikeBatteryHealthToViewStateMapper {
    BikeBatteryHealthToViewStateMapper(
        formatter: makeBatteryHealthFormatter(),
        analyzer: BatteryHealthAnalyzer(),
        captureFormatter: BatteryHealthCaptureFormatter(
            dateFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
        ),
        now: now
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
        logger: ChargeControlLogStore(isRecording: { true }),
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
