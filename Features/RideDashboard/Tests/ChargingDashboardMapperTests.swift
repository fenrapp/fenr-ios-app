import BikeDomain
import Foundation
import RideDashboard
import Testing

@Suite("Charging dashboard mapper")
struct ChargingDashboardMapperTests {
    @Test("Maps confirmed charging values and indicators")
    func mapsChargingTelemetry() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 82),
            statusFlags: BikeStatusFlags(
                isCharging: true,
                isFaultActive: true,
                isBrakeActive: true,
                indicatorState: BikeIndicatorState(isHighBeamOn: true, isLeftBlinkerOn: true)
            )
        )
        let batteryHealth = BikeBatteryHealth(
            dcBusVoltage: .known(volts: 388),
            temperatures: [
                .init(position: 1, celsius: 20),
                .init(position: 2, celsius: 24)
            ],
            chargingStatus: BikeChargingStatus(
                requestedCurrentAmperes: 14,
                reportedCurrentAmperes: 13.6,
                maximumCurrentAmperes: 16,
                maximumPowerWatts: 6_200,
                targetCellVoltageVolts: 4.2,
                maximumStateOfChargePercent: 100
            )
        )

        let state = ChargingDashboardMapper(locale: Locale(identifier: "es_ES")).map(
            telemetry: telemetry,
            batteryHealth: batteryHealth
        )

        #expect(state.batteryPercent == 82)
        #expect(state.maximumPower == .init(value: 6.2, unit: "kW"))
        #expect(state.reportedCurrent == .init(value: 13.6, unit: "A"))
        #expect(state.batteryTemperature == .init(value: 22, unit: "°C"))
        #expect(state.targetStateOfChargePercent == 100)
        #expect(state.estimatedTimeRemaining != nil)
        #expect(state.isHighBeamOn)
        #expect(state.isLeftBlinkerOn)
        #expect(state.isBrakeActive)
        #expect(state.isFaultActive)
    }

    @Test("Leaves charger fields unavailable outside charging telemetry")
    func mapsUnavailableChargerValues() {
        let state = ChargingDashboardMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 60)),
            batteryHealth: BikeBatteryHealth()
        )

        #expect(state.batteryPercent == 60)
        #expect(state.maximumPower == nil)
        #expect(state.reportedCurrent == nil)
        #expect(state.batteryTemperature == nil)
        #expect(state.targetStateOfChargePercent == nil)
        #expect(state.estimatedTimeRemaining == nil)
    }

    @Test("Uses the selected pack capacity for the charging ETA")
    func usesSelectedBatteryPackCapacity() {
        let telemetry = BikeTelemetry(batteryLevel: .known(percent: 50))
        let batteryHealth = BikeBatteryHealth(
            dcBusVoltage: .known(volts: 400),
            chargingStatus: BikeChargingStatus(
                requestedCurrentAmperes: 10,
                reportedCurrentAmperes: 10,
                maximumCurrentAmperes: 10,
                maximumPowerWatts: 4_000,
                targetCellVoltageVolts: 4.2,
                maximumStateOfChargePercent: 100
            )
        )

        let smallerPack = ChargingDashboardMapper(
            batteryPackCapacity: .sixPointEightKilowattHours,
            locale: Locale(identifier: "en_US")
        ).map(telemetry: telemetry, batteryHealth: batteryHealth)
        let largerPack = ChargingDashboardMapper(
            batteryPackCapacity: .sevenPointTwoKilowattHours,
            locale: Locale(identifier: "en_US")
        ).map(telemetry: telemetry, batteryHealth: batteryHealth)

        #expect(smallerPack.estimatedTimeRemaining != nil)
        #expect(largerPack.estimatedTimeRemaining != nil)
        #expect(smallerPack.estimatedTimeRemaining != largerPack.estimatedTimeRemaining)
    }
}
