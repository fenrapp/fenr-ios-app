import BikeDomain
import ChargeControl
import EnvironmentDomain
import Foundation
import RuntimeConfiguration
import SettingsDomain

#if DEBUG
@MainActor
enum RideDashboardPreviewFactory {
    static func makeViewModel(state: RideDashboardViewState) -> RideDashboardViewModel {
        let repository = RideDashboardPreviewRepository()
        let viewModel = RideDashboardViewModel(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: PreviewAppSettingsRepository()),
                observeDeviceSpeed: .init(repository: PreviewDeviceSpeedRepository()),
                readBikeStatusSnapshot: .init(repository: repository)
            ),
            mapper: RideDashboardMapperFactory.makeRideMapper(locale: .autoupdatingCurrent),
            deviceSpeedResolver: DeviceSpeedResolver(
                now: Date.init,
                maximumAccuracyMetersPerSecond: 5,
                maximumSampleAge: FENRRuntimeConstants.RideDashboard.deviceSpeedMaximumSampleAge
            ),
            reconnectionGracePeriod: FENRRuntimeConstants.RideDashboard.reconnectionGracePeriod
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

@MainActor
enum ChargingDashboardPreviewFactory {
    static func makeViewModel(state: ChargingDashboardViewState) -> ChargingDashboardViewModel {
        let repository = RideDashboardPreviewRepository()
        let locale = Locale.autoupdatingCurrent
        let makeMapper: @Sendable (AppSettings) -> ChargingDashboardMapper = { settings in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale)
        }
        let viewModel = ChargingDashboardViewModel(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeBatteryHealth: .init(repository: repository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository),
                observeSettings: .init(repository: PreviewAppSettingsRepository())
            ),
            chargeControl: ChargeControlSession(
                useCases: .init(
                    prepare: .init(repository: repository),
                    setPowerLimit: .init(repository: repository),
                    setTarget: .init(repository: repository)
                ),
                logger: ChargeControlLogStore(),
                stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
                taskScheduler: ChargeControlTaskScheduler()
            ),
            mapper: makeMapper(AppSettings()),
            makeMapper: makeMapper
        )
        viewModel.setPreviewState(state)
        return viewModel
    }
}

private actor PreviewAppSettingsRepository: AppSettingsRepository {
    func load() -> AppSettings { .init() }
    func save(_: AppSettings) {}
    func observe() -> AsyncStream<AppSettings> { .init { $0.finish() } }
}

private actor PreviewDeviceSpeedRepository: DeviceSpeedRepository {
    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> { .init { $0.finish() } }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}
}

private actor RideDashboardPreviewRepository: BikeRepository, BikeBatteryHealthRepository {
    func start() async {}
    func stop() async {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { $0.finish() } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { $0.finish() } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { $0.finish() } }
    func startBatteryHealthMonitoring() async throws {}
    func stopBatteryHealthMonitoring() async {}
    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> { .init { $0.finish() } }
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> { .init { $0.finish() } }
}
#endif
