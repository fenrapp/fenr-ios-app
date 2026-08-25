import BikeDomain
import EnvironmentDomain
import Foundation
import RideDashboard
import RuntimeConfiguration
import SettingsDomain

@MainActor
struct RideDashboardDependencyContainer {
    func makeViewModel(
        repository: BikeRepository,
        settingsRepository: AppSettingsRepository,
        deviceSpeedRepository: DeviceSpeedRepository
    ) -> RideDashboardViewModel {
        RideDashboardViewModel(
            useCases: .init(
                observeTelemetry: ObserveBikeTelemetryUseCase(repository: repository),
                observeConnection: ObserveBikeConnectionUseCase(repository: repository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository),
                observeDeviceSpeed: ObserveDeviceSpeedUseCase(repository: deviceSpeedRepository),
                readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase(repository: repository)
            ),
            mapper: RideDashboardMapperFactory.makeRideMapper(locale: .autoupdatingCurrent),
            deviceSpeedResolver: DeviceSpeedResolver(
                now: Date.init,
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            ),
            reconnectionGracePeriod: FENRRuntimeConstants.RideDashboard.reconnectionGracePeriod
        )
    }
}
