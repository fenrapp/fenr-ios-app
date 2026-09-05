import BatteryHealth
import BikeDomain
import ChargeControl
import Foundation
import MeasurementPresentation
import SettingsDomain
import VehicleSession

@MainActor
struct BatteryHealthDependencyContainer {
    var isDemo = false

    func makeBatteryHealthViewModel(
        repository: any BikeBatteryHealthRepository,
        vehicleSession: any VehicleSessionService,
        chargeControl: ChargeControlSession
    ) -> BatteryHealthViewModel {
        let locale = Locale.autoupdatingCurrent
        let analyzer = BatteryHealthAnalyzer()
        let captureFormatter = BatteryHealthCaptureFormatter(
            dateFormatStyle: Date.FormatStyle(date: .omitted, time: .standard), isDemo: isDemo
        )
        return BatteryHealthViewModel(
            useCases: .init(
                observeCaptures: ObserveBatteryDatasetCapturesUseCase(repository: repository)
            ),
            vehicleSession: vehicleSession,
            mapper: Self.makeMapper(
                measurementSystem: .system,
                locale: locale,
                analyzer: analyzer,
                captureFormatter: captureFormatter
            ),
            makeMapper: { measurementSystem in
                Self.makeMapper(
                    measurementSystem: measurementSystem,
                    locale: locale,
                    analyzer: analyzer,
                    captureFormatter: captureFormatter
                )
            },
            chargeControl: chargeControl,
            captureFormatter: captureFormatter
        )
    }

    private static func makeMapper(
        measurementSystem: MeasurementSystem,
        locale: Locale,
        analyzer: BatteryHealthAnalyzer,
        captureFormatter: BatteryHealthCaptureFormatter
    ) -> BikeBatteryHealthToViewStateMapper {
        BikeBatteryHealthToViewStateMapper(
            formatter: BatteryHealthFormatter(
                locale: locale,
                measurementMapper: VehicleMeasurementMapper(
                    measurementSystem: measurementSystem.resolved(for: locale)
                ),
                measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale)
            ),
            analyzer: analyzer,
            captureFormatter: captureFormatter,
            now: Date.init
        )
    }
}
