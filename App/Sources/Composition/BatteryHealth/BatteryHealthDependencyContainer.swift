import BatteryHealth
import BikeDomain
import ChargeControl
import Foundation
import MeasurementPresentation
import SettingsDomain

@MainActor
struct BatteryHealthDependencyContainer {
    func makeBatteryHealthViewModel(
        repository: any BikeBatteryHealthRepository,
        settingsRepository: AppSettingsRepository,
        chargeControl: ChargeControlSession
    ) -> BatteryHealthViewModel {
        let locale = Locale.autoupdatingCurrent
        return BatteryHealthViewModel(
            useCases: .init(
                startMonitoring: StartBatteryHealthMonitoringUseCase(repository: repository),
                stopMonitoring: StopBatteryHealthMonitoringUseCase(repository: repository),
                observeHealth: ObserveBikeBatteryHealthUseCase(repository: repository),
                observeCaptures: ObserveBatteryDatasetCapturesUseCase(repository: repository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository)
            ),
            mapper: makeMapper(measurementSystem: .system, locale: locale),
            makeMapper: { [self] measurementSystem in
                makeMapper(measurementSystem: measurementSystem, locale: locale)
            },
            chargeControl: chargeControl,
            captureTimeFormatStyle: Date.FormatStyle(date: .omitted, time: .standard)
        )
    }

    private func makeMapper(
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
