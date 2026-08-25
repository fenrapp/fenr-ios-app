import BikeDomain
import Foundation
import RuntimeConfiguration
import SettingsDomain

#if DEBUG
@MainActor
enum WatchDashboardPreviewFactory {
    static func ride() -> WatchDashboardViewModel {
        let repository = WatchDashboardPreviewRepository()
        let viewModel = WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: WatchDashboardPreviewSettingsRepository()
            ),
            mapper: WatchDashboardMapperFactory.make(
                locale: .autoupdatingCurrent,
                now: Date.init,
                telemetryFreshnessInterval: FENRRuntimeConstants.Telemetry.freshnessInterval
            ),
            maximumDebugEvents: 12
        )
        return viewModel
    }
}

private actor WatchDashboardPreviewRepository: BikeRepository, BikeBatteryHealthRepository {
    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func readBikeStatusSnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { _ in } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { _ in } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { _ in } }
    func startBatteryHealthMonitoring() async throws {}
    func stopBatteryHealthMonitoring() async {}
    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> { .init { _ in } }
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> { .init { _ in } }
}

private actor WatchDashboardPreviewSettingsRepository: AppSettingsRepository {
    func load() -> AppSettings { .init() }
    func save(_: AppSettings) {}

    func observe() -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
}
#endif
