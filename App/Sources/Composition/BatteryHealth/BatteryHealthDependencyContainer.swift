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
                measurementSystem: measurementSystem.resolved(for: locale)
            )
        )
    }
}
