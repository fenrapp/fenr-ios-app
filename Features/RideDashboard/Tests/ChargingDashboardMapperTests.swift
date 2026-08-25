import BikeDomain
import ChargeControl
import Foundation
import RideDashboard
import SettingsDomain
import Testing

@Suite("Charging dashboard mapper")
struct ChargingDashboardMapperTests {
    @Test("Maps confirmed charging values")
    func mapsChargingTelemetry() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 82)
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

        let state = makeMapper(locale: Locale(identifier: "es_ES")).map(
            telemetry: telemetry,
            batteryHealth: batteryHealth
        )

        #expect(state.gauge.batteryPercent == 82)
        #expect(state.maximumPower == .init(valueText: "6,2", unitText: "kW", animationValue: 6.2))
        #expect(state.reportedCurrent == .init(valueText: "13,6", unitText: "A", animationValue: 13.6))
        #expect(state.batteryTemperature == .init(valueText: "22", unitText: "°C", animationValue: 22))
        #expect(state.gauge.targetPercent == 100)
        #expect(state.gauge.estimatedTimeRemaining != nil)
        #expect(state.gauge.readout.title.hasPrefix("ETA: "))
        #expect(state.gauge.readout.usesEstimatedTimeStyle)
        #expect(state.gauge.readout.accessibilityLabel == "Charging 82 percent. Target 100 percent")
    }

    @Test("Leaves charger fields unavailable outside charging telemetry")
    func mapsUnavailableChargerValues() {
        let state = makeMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 60)),
            batteryHealth: BikeBatteryHealth()
        )

        #expect(state.gauge.batteryPercent == 60)
        #expect(state.maximumPower == .init())
        #expect(state.reportedCurrent == .init())
        #expect(state.batteryTemperature == .init())
        #expect(state.gauge.targetPercent == nil)
        #expect(state.gauge.estimatedTimeRemaining == nil)
        #expect(state.gauge.readout.title == "CHARGING")
        #expect(!state.gauge.readout.usesEstimatedTimeStyle)
        #expect(state.gauge.readout.accessibilityLabel == "Charging 60 percent")
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

        let smallerPack = makeMapper(
            batteryPackCapacity: .sixPointEightKilowattHours,
            locale: Locale(identifier: "en_US")
        ).map(telemetry: telemetry, batteryHealth: batteryHealth)
        let largerPack = makeMapper(
            batteryPackCapacity: .sevenPointTwoKilowattHours,
            locale: Locale(identifier: "en_US")
        ).map(telemetry: telemetry, batteryHealth: batteryHealth)

        #expect(smallerPack.gauge.estimatedTimeRemaining == "51m")
        #expect(largerPack.gauge.estimatedTimeRemaining == "54m")
    }

    @Test("Identifies full-charge balancing")
    func identifiesFullChargeBalancing() {
        let state = makeMapper().map(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 100)),
            batteryHealth: BikeBatteryHealth(balancingCellIndexes: [0])
        )

        #expect(state.gauge.isBalancingAtFullCharge)
        #expect(state.gauge.readout.title == "BALANCING")
        #expect(state.gauge.readout.accessibilityLabel == "Balancing 100 percent")
    }

    @Test("Maps charge control into dashboard presentation state")
    func mapsChargeControlPresentation() {
        let control = ChargeControlState(
            isVisible: true,
            isEnabled: true,
            selectedWatts: 1_700,
            confirmedWatts: 1_500,
            minimumWatts: 300,
            maximumWatts: 3_300,
            stepWatts: 100,
            selectedTargetPercent: 78,
            confirmedTargetPercent: 80,
            minimumTargetPercent: 1,
            maximumTargetPercent: 100,
            targetStepPercent: 1,
            phase: .updating
        )
        let health = BikeBatteryHealth(
            chargingStatus: .init(
                requestedCurrentAmperes: 10,
                reportedCurrentAmperes: 10,
                maximumCurrentAmperes: 10,
                maximumPowerWatts: 1_500,
                targetCellVoltageVolts: 4.2,
                maximumStateOfChargePercent: 80
            )
        )

        let state = makeMapper().map(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 55)),
            batteryHealth: health,
            chargeControl: control
        )

        #expect(state.gauge.targetPercent == 78)
        let expectedControl = ChargingDashboardControlViewState(
            isEnabled: true,
            power: .init(selected: 1_700, minimum: 300, maximum: 3_300, step: 100),
            target: .init(selected: 78, minimum: 1, maximum: 100, step: 1),
            status: .init(text: "UPDATING", isError: false)
        )
        #expect(state.gauge.control == expectedControl)
    }

    private func makeMapper(
        batteryPackCapacity: BatteryPackCapacity = .sevenPointTwoKilowattHours,
        locale: Locale = Locale(identifier: "en_US")
    ) -> ChargingDashboardMapper {
        RideDashboardMapperFactory.makeChargingMapper(
            settings: AppSettings(batteryPackCapacity: batteryPackCapacity),
            locale: locale
        )
    }
}
