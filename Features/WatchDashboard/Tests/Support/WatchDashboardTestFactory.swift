import Foundation
@testable import WatchDashboard

@MainActor
enum WatchDashboardTestFactory {
    static func make(repository: WatchDashboardRepository) -> WatchDashboardViewModel {
        WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: WatchDashboardSettingsRepository()
            ),
            mapper: WatchDashboardMapperFactory.make(
                locale: Locale(identifier: "en_US"),
                now: Date.init,
                telemetryFreshnessInterval: 60
            ),
            maximumDebugEvents: 12
        )
    }
}
