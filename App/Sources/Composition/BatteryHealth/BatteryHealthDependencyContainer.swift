import BatteryHealth
import BikeDomain
import Foundation
import SettingsDomain

@MainActor
struct BatteryHealthDependencyContainer {
    func makeBatteryHealthViewModel(
        repository: any BikeBatteryHealthRepository,
        settingsRepository: AppSettingsRepository
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
            }
        )
    }

    private func makeMapper(
        measurementSystem: MeasurementSystem,
        locale: Locale
    ) -> BikeBatteryHealthToViewStateMapper {
        BikeBatteryHealthToViewStateMapper(
            formatter: BatteryHealthFormatter(
                locale: locale,
                measurementFormatters: makeMeasurementFormatters(
                    measurementSystem: measurementSystem,
                    locale: locale
                )
            )
        )
    }

    private func makeMeasurementFormatters(
        measurementSystem: MeasurementSystem,
        locale: Locale
    ) -> BatteryHealthMeasurementFormatters {
        BatteryHealthMeasurementFormatters(
            voltageFormatter: makeMeasurementFormatter(
                locale: locale,
                unitOptions: .providedUnit
            ),
            temperatureFormatter: makeMeasurementFormatter(
                locale: locale,
                unitOptions: .providedUnit
            ),
            currentFormatter: makeMeasurementFormatter(
                locale: locale,
                unitOptions: .providedUnit
            ),
            powerFormatter: makeMeasurementFormatter(
                locale: locale,
                unitOptions: .naturalScale
            ),
            temperatureUnit: measurementSystem.resolved(for: locale) == .metric ? .celsius : .fahrenheit
        )
    }

    private func makeMeasurementFormatter(
        locale: Locale,
        unitOptions: MeasurementFormatter.UnitOptions
    ) -> MeasurementFormatter {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = unitOptions
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }
}
