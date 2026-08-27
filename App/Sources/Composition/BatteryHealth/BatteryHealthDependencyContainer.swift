import BatteryHealth
import BikeDomain
import ChargeControl
import Foundation
import MeasurementPresentation
import SettingsDomain
import VehicleSession

@MainActor
struct BatteryHealthDependencyContainer {
    func makeBatteryHealthViewModel(
        repository: any BikeBatteryHealthRepository,
        vehicleSession: any VehicleSessionService,
        chargeControl: ChargeControlSession
    ) -> BatteryHealthViewModel {
        let locale = Locale.autoupdatingCurrent
        return BatteryHealthViewModel(
            useCases: .init(
                observeCaptures: ObserveBatteryDatasetCapturesUseCase(repository: repository)
            ),
            vehicleSession: vehicleSession,
            mapper: Self.makeMapper(measurementSystem: .system, locale: locale),
            makeMapper: { measurementSystem in
                Self.makeMapper(measurementSystem: measurementSystem, locale: locale)
            },
            chargeControl: chargeControl,
            captureTimeFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
        )
    }

    private static func makeMapper(
        measurementSystem: MeasurementSystem,
        locale: Locale
    ) -> BikeBatteryHealthToViewStateMapper {
        BikeBatteryHealthToViewStateMapper(
            formatter: BatteryHealthFormatter(
                locale: locale,
                measurementMapper: VehicleMeasurementMapper(
                    measurementSystem: measurementSystem.resolved(for: locale)
                ),
                measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
            )
        )
    }
}
