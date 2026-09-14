import Foundation
import RideDashboard
import RuntimeConfiguration

extension AppDependencyContainer {
    func makeBikeLiveActivityController() -> BikeLiveActivityController {
        let activityClient = ActivityKitBikeLiveActivityClient(isDemo: experienceOptions.isDemo)
        let locale = Locale.autoupdatingCurrent
        return BikeLiveActivityController(
            vehicleSession: vehicleSession,
            activityClient: activityClient,
            clock: SystemBikeLiveActivityClock(),
            timing: .live,
            continuityPolicy: RideDashboardContinuityPolicy(),
            updatePolicy: BikeLiveActivityUpdatePolicy(
                updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval
            ),
            reconnectionNoticeDelay: FENRRuntimeConstants.RideDashboard.reconnectionNoticeDelay,
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
