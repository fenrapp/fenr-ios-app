import ChargeControl
import Foundation
import RideDashboard
import SettingsDomain
import VehicleSession

@MainActor
struct ChargingDashboardDependencyContainer {
    func makeViewModel(
        vehicleSession: any VehicleSessionService,
        chargeControl: ChargeControlSession
    ) -> ChargingDashboardViewModel {
        let locale = Locale.autoupdatingCurrent
        let makeMapper: @Sendable (AppSettings, String?) -> ChargingDashboardMapper = { settings, vin in
            RideDashboardMapperFactory.makeChargingMapper(settings: settings, locale: locale, vin: vin)
        }
        return ChargingDashboardViewModel(
            vehicleSession: vehicleSession,
            chargeControl: chargeControl,
            mapper: makeMapper(AppSettings(), nil),
            makeMapper: makeMapper
        )
    }
}
