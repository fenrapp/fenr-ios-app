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
            batteryLevel: .known(percent: 82),
            statusFlags: .init(isCharging: true, isChargerConnected: true)
        )
        let batteryHealth = BikeBatteryHealth(
            dcBusVoltage: .known(volts: 388),
            chargeState: .charging,
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
            ),
            lastUpdated: Date()
        )

        let state = makeMapper(locale: Locale(identifier: "es_ES")).map(
            telemetry: telemetry,
            batteryHealth: batteryHealth
        )

        #expect(state.batteryPercent == 82)
        #expect(state.maximumPower == .init(valueText: "6,2", unitText: "kW", animationValue: 6.2))
        #expect(state.chargingPower.valueText == "5,3")
        #expect(state.chargingPower.unitText == "kW")
        #expect(abs((state.chargingPower.animationValue ?? .zero) - 5.2768) < 0.000_001)
        #expect(state.reportedCurrent == .init(valueText: "13,6", unitText: "A", animationValue: 13.6))
        #expect(state.batteryTemperature == .init(valueText: "22", unitText: "°C", animationValue: 22))
        #expect(state.batteryTemperatureEmphasis == .normal)
        #expect(state.targetPercent == 100)
        #expect(state.estimatedTimeRemaining != nil)
        #expect(state.readout.title.hasPrefix("ETA: "))
        #expect(state.readout.subtitle == "TARGET 100%")
        #expect(state.readout.accessibilityLabel == "Charging 82 percent. Target 100 percent")
    }

    @Test("Leaves charger fields unavailable outside charging telemetry")
    func mapsUnavailableChargerValues() {
        let state = makeMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 60)),
            batteryHealth: BikeBatteryHealth()
        )

        #expect(state.batteryPercent == 60)
        #expect(state.maximumPower == .init())
        #expect(state.chargingPower == .init())
        #expect(state.reportedCurrent == .init())
        #expect(state.batteryTemperature == .init())
        #expect(state.batteryTemperatureEmphasis == .unavailable)
        #expect(state.targetPercent == nil)
        #expect(state.estimatedTimeRemaining == nil)
        #expect(state.readout.title == "CHARGER")
        #expect(state.readout.subtitle == "DISCONNECTED")
        #expect(state.readout.emphasis == .critical)
        #expect(!state.readout.allowsControl)
        #expect(!state.readout.showsProgress)
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

        #expect(smallerPack.estimatedTimeRemaining == "51m")
        #expect(largerPack.estimatedTimeRemaining == "54m")
    }

    @Test("Identifies full-charge balancing")
    func identifiesFullChargeBalancing() {
        let state = makeMapper().map(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 100)),
            batteryHealth: BikeBatteryHealth(balancingCellIndexes: [0])
        )

        #expect(state.isBalancingAtFullCharge)
        #expect(state.readout.title == "BALANCING")
        #expect(state.readout.subtitle == "1 CELL ACTIVE")
        #expect(state.readout.emphasis == .balancing)
        #expect(!state.readout.allowsControl)
        #expect(state.activeBalancingCells == .init(valueText: "1", animationValue: 1))
        #expect(state.readout.accessibilityLabel == "Balancing 100 percent")
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

        #expect(state.targetPercent == 78)
        let expectedControl = ChargingDashboardControlViewState(
            isEnabled: true,
            power: .init(selected: 1_700, minimum: 300, maximum: 3_300, step: 100),
            target: .init(selected: 78, minimum: 1, maximum: 100, step: 1),
            status: .init(text: "UPDATING", isError: false)
        )
        #expect(state.control == expectedControl)
    }

    @Test("Maps failed charge control feedback")
    func mapsFailedChargeControlFeedback() {
        let state = makeMapper().map(
            telemetry: chargingTelemetry(percent: 55),
            batteryHealth: chargingHealth(),
            chargeControl: ChargeControlState(phase: .failed)
        )

        #expect(state.control.status == .init(text: "UPDATE FAILED", isError: true))
    }

    @Test("Represents a connected idle charger")
    func mapsConnectedIdleCharger() {
        let state = makeMapper().map(
            telemetry: BikeTelemetry(
                batteryLevel: .known(percent: 68),
                statusFlags: .init(isChargerConnected: true)
            ),
            batteryHealth: BikeBatteryHealth(
                chargeState: .connected,
                chargingStatus: chargingStatus(),
                lastUpdated: Date()
            )
        )

        #expect(state.readout.title == "CHARGER")
        #expect(state.readout.subtitle == "CONNECTED · IDLE")
        #expect(state.readout.systemImage == "powerplug.fill")
        #expect(state.readout.emphasis == .warning)
        #expect(!state.readout.allowsControl)
        #expect(!state.readout.showsProgress)
    }

    @Test("Represents unavailable charger data")
    func mapsUnavailableChargingData() {
        let state = makeMapper().map(
            telemetry: BikeTelemetry(
                batteryLevel: .known(percent: 68),
                statusFlags: .init(isCharging: true, isChargerConnected: true)
            ),
            batteryHealth: BikeBatteryHealth(lastUpdated: Date())
        )

        #expect(state.readout.title == "CHARGING")
        #expect(state.readout.subtitle == "DATA UNAVAILABLE")
        #expect(state.readout.systemImage == "exclamationmark.triangle.fill")
        #expect(state.readout.emphasis == .warning)
        #expect(!state.readout.allowsControl)
        #expect(!state.readout.showsProgress)
    }

    @Test("Maps semantic charging temperature bands")
    func mapsSemanticTemperatureBands() {
        let cases: [(Double, ChargingDashboardViewState.TemperatureEmphasis)] = [
            (3.9, .critical),
            (4, .warning),
            (9.9, .warning),
            (10, .normal),
            (49.9, .normal),
            (50, .warning),
            (59.9, .warning),
            (60, .critical)
        ]

        for (temperature, emphasis) in cases {
            let state = makeMapper().map(
                telemetry: chargingTelemetry(percent: 55),
                batteryHealth: chargingHealth(temperature: temperature)
            )
            #expect(state.batteryTemperatureEmphasis == emphasis)
        }
    }

    private func chargingTelemetry(percent: Int) -> BikeTelemetry {
        BikeTelemetry(
            batteryLevel: .known(percent: percent),
            statusFlags: .init(isCharging: true, isChargerConnected: true)
        )
    }

    private func chargingHealth(temperature: Double = 24) -> BikeBatteryHealth {
        BikeBatteryHealth(
            dcBusVoltage: .known(volts: 400),
            chargeState: .charging,
            temperatures: [.init(position: 1, celsius: temperature)],
            chargingStatus: chargingStatus(),
            lastUpdated: Date()
        )
    }

    private func chargingStatus() -> BikeChargingStatus {
        BikeChargingStatus(
            requestedCurrentAmperes: 10,
            reportedCurrentAmperes: 10,
            maximumCurrentAmperes: 10,
            maximumPowerWatts: 4_000,
            targetCellVoltageVolts: 4.2,
            maximumStateOfChargePercent: 100
        )
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
