import BikeDomain
import Testing

@Suite("Bike power telemetry calculator")
struct BikePowerTelemetryCalculatorTests {
    @Test("Estimated power formula matches the observed positive-current sample")
    func observedPositiveCurrentFormula() {
        let calculation = BikePowerTelemetryCalculator().calculate(
            dcBusVolts: 386.5,
            batteryCurrentCandidateAmperes: 3
        )

        #expect(calculation.electricalPowerWatts == 1_159.5)
        #expect(calculation.starkMotorPowerHorsepower == 1.27545)
    }

    @Test("Estimated power formula preserves current sign")
    func negativeCurrent() {
        let calculation = BikePowerTelemetryCalculator().calculate(
            dcBusVolts: 400,
            batteryCurrentCandidateAmperes: -25
        )

        #expect(calculation.electricalPowerWatts == -10_000)
        #expect(calculation.starkMotorPowerHorsepower == -11)
    }
}
