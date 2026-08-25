import BikeDomain
import ChargeControl
import Foundation
import RideDashboard
import SettingsDomain

@MainActor
struct ChargingDashboardDependencyContainer {
    func makeViewModel(
        repository: any BikeRepository & BikeBatteryHealthRepository,
        settingsRepository: AppSettingsRepository,
        chargeControl: ChargeControlSession
    ) -> ChargingDashboardViewModel {
        let locale = Locale.autoupdatingCurrent
        let makeMapper: @Sendable (AppSettings) -> ChargingDashboardMapper = { settings in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale)
        }
        return ChargingDashboardViewModel(
            useCases: .init(
                observeTelemetry: ObserveBikeTelemetryUseCase(repository: repository),
                observeBatteryHealth: ObserveBikeBatteryHealthUseCase(repository: repository),
                startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase(repository: repository),
                stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase(repository: repository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository)
            ),
            chargeControl: chargeControl,
            mapper: makeMapper(AppSettings()),
            makeMapper: makeMapper
        )
    }
}
