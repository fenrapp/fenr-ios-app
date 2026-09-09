import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain

enum ChargingTemperatureReportTestFactory {
    static func state(
        temperatures: [Double], units: MeasurementSystem, locale: String = "en_US"
    ) -> ChargingDashboardViewState {
        let mapper = RideDashboardMapperFactory.makeChargingMapper(
            settings: .init(measurementSystem: units), locale: .init(identifier: locale)
        )
        return mapper.map(
            telemetry: .init(statusFlags: .init(isCharging: true, isChargerConnected: true)),
            batteryHealth: .init(temperatures: temperatures.enumerated().map {
                .init(position: $0.offset + 1, celsius: $0.element)
            })
        )
    }
}
