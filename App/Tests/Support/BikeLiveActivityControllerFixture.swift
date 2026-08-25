import Foundation
import RideDashboard
import RuntimeConfiguration

@MainActor
final class BikeLiveActivityControllerFixture {
    let repository = BikeLiveActivityRepository()
    let settingsRepository = BikeLiveActivitySettingsRepository()
    let activityClient = FakeBikeLiveActivityClient()
    let clock = FakeBikeLiveActivityClock()
    let controller: BikeLiveActivityController

    init() {
        let locale = Locale(identifier: "en_US")
        controller = BikeLiveActivityController(
            useCases: .init(
                observeTelemetry: .init(repository: repository),
                observeBatteryHealth: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeSettings: .init(repository: settingsRepository),
                startBatteryHealthMonitoring: .init(repository: repository),
                stopBatteryHealthMonitoring: .init(repository: repository)
            ),
            activityClient: activityClient,
            clock: clock,
            updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval,
            stateMapper: BikeLiveActivityStateMapper(
                makeDashboardMapper: { settings in
                    RideDashboardMapperFactory.makeChargingMapper(
                        settings: settings,
                        locale: locale
                    )
                },
                makeSpeedMapper: { measurementSystem in
                    RideDashboardMapperFactory.makeMeasurementMapper(
                        measurementSystem: measurementSystem,
                        locale: locale
                    )
                },
                telemetryFreshnessInterval: FENRRuntimeConstants.Telemetry.freshnessInterval,
                completeBatteryPercent: FENRRuntimeConstants.LiveActivity.completeBatteryPercent
            )
        )
    }
}
