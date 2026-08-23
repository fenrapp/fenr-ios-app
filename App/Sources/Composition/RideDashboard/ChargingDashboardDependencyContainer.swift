import BikeDomain
import RideDashboard
import SettingsDomain

@MainActor
struct ChargingDashboardDependencyContainer {
    func makeViewModel(
        repository: any BikeRepository & BikeBatteryHealthRepository,
        settingsRepository: AppSettingsRepository
    ) -> ChargingDashboardViewModel {
        ChargingDashboardViewModel(
            useCases: .init(
                observeTelemetry: ObserveBikeTelemetryUseCase(repository: repository),
                observeBatteryHealth: ObserveBikeBatteryHealthUseCase(repository: repository),
                startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase(repository: repository),
                stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase(repository: repository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository)
            )
        )
    }
}
