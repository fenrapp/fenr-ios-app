import BikeDomain
import EnvironmentDomain
import Foundation
import RideDashboard
import RideSessionDomain
import RuntimeConfiguration
import SettingsDomain

@MainActor
struct CurrentTripCardDependencyContainer {
    func makeViewModels(
        repository: BikeRepository,
        settingsRepository: AppSettingsRepository,
        deviceSpeedRepository: DeviceSpeedRepository,
        rideTripRepository: RideTripRepository,
        applicationSessionID: UUID
    ) -> CurrentTripCardViewModels {
        let statisticsViewModel = makeStatisticsViewModel(
            settingsRepository: settingsRepository,
            rideTripRepository: rideTripRepository
        )
        let currentTripViewModel = CurrentTripCardViewModel(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: settingsRepository),
                observeDeviceSpeed: .init(repository: deviceSpeedRepository),
                prepareRideTripSession: .init(repository: rideTripRepository),
                saveActiveRideTrip: .init(repository: rideTripRepository),
                completeRideTrip: .init(repository: rideTripRepository)
            ),
            mapper: RideDashboardMapperFactory.makeCurrentTripMapper(locale: .autoupdatingCurrent),
            deviceSpeedResolver: DeviceSpeedResolver(
                now: Date.init,
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            ),
            applicationSessionID: applicationSessionID,
            now: Date.init,
            onHistoryChanged: statisticsViewModel.invalidate
        )
        return CurrentTripCardViewModels(
            currentTrip: currentTripViewModel,
            statistics: statisticsViewModel
        )
    }

    private func makeStatisticsViewModel(
        settingsRepository: AppSettingsRepository,
        rideTripRepository: RideTripRepository
    ) -> TripStatisticsCardViewModel {
        TripStatisticsCardViewModel(
            useCases: .init(
                loadStatistics: .init(
                    repository: rideTripRepository,
                    aggregator: RideTripStatisticsAggregator()
                ),
                observeSettings: .init(repository: settingsRepository)
            ),
            mapper: RideDashboardMapperFactory.makeTripStatisticsMapper(
                locale: .autoupdatingCurrent
            )
        )
    }
}

@MainActor
struct CurrentTripCardViewModels {
    let currentTrip: CurrentTripCardViewModel
    let statistics: TripStatisticsCardViewModel
}
