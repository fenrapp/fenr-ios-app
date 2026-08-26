import RideSessionDomain
import SettingsDomain

public struct TripStatisticsCardUseCases: Sendable {
    let loadStatistics: LoadRideTripStatisticsUseCase
    let observeSettings: ObserveAppSettingsUseCase

    public init(
        loadStatistics: LoadRideTripStatisticsUseCase,
        observeSettings: ObserveAppSettingsUseCase
    ) {
        self.loadStatistics = loadStatistics
        self.observeSettings = observeSettings
    }
}
