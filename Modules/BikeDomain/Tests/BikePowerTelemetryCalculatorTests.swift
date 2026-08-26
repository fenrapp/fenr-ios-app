import BikeDomain
import Testing

@Suite("Bike power telemetry calculator")
struct BikePowerTelemetryCalculatorTests {
    @Test("Validated power formula converts voltage and current into watts and horsepower")
    func starkFormula() {
        let calculation = BikePowerTelemetryCalculator().calculate(
            dcBusVolts: 400,
            batteryCurrentAmperes: 25
        )

        #expect(calculation.electricalPowerWatts == 10_000)
        #expect(calculation.starkMotorPowerHorsepower == 11)
    }

    @Test("Validated power formula preserves current sign")
    func negativeCurrent() {
        let calculation = BikePowerTelemetryCalculator().calculate(
            dcBusVolts: 400,
            batteryCurrentAmperes: -25
        )

        #expect(calculation.electricalPowerWatts == -10_000)
        #expect(calculation.starkMotorPowerHorsepower == -11)
    }
}
