@testable import BikeDiagnostics
import BikeDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Bike diagnostics power and battery telemetry")
struct BikeDiagnosticsPowerBatteryTests {
    @Test("Validated fields and electrical candidates are distinguished")
    func mapsPowerAndBatteryMetrics() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { await repository.telemetryObserverCount() == 1 })

        await repository.sendTelemetry(makeTelemetry())
        #expect(await waitUntil {
            viewModel.viewState.powerMetrics.contains {
                $0.id == "electricalPower" && $0.value.contains("10.000 W")
            }
        })

        #expect(viewModel.viewState.powerMetrics.contains {
            $0.id == "electricalPower"
                && $0.title == "Estimated electrical power"
                && $0.value == "10.000 W / 10 kW"
        })
        #expect(viewModel.viewState.powerMetrics.contains {
            $0.id == "starkHorsepower"
                && $0.title == "Estimated Stark power"
                && $0.value == "11 hp"
        })
        #expect(viewModel.viewState.batteryMetrics.contains {
            $0.id == "batteryCurrent"
                && $0.title == "Battery current candidate"
                && $0.value == "25 A (raw 25)"
        })
        #expect(viewModel.viewState.batteryMetrics.contains {
            $0.id == "positiveVoltageCandidate"
                && $0.title == "Positive BMS voltage candidate"
                && $0.value == "raw 408"
        })
        #expect(viewModel.viewState.batteryMetrics.contains {
            $0.id == "positiveTemp"
                && $0.title == "Positive BMS temperature candidate"
                && $0.value == "25,34 C (raw 2534)"
        })
    }

    private func makeTelemetry() -> BikeTelemetry {
        let updatedAt = Date(timeIntervalSince1970: 0)
        let bms = BikeBMSSignalsTelemetry(
            voltageCandidateRaw: 408,
            temperatureRaw: 2_534,
            temperatureCelsius: 25.34,
            humidityRaw: 5_012,
            humidityPercent: 50.12
        )
        return BikeTelemetry(
            powerTelemetry: .init(
                electricalPowerWatts: 10_000,
                calculatedPowerUpdatedAt: updatedAt
            ),
            batteryTelemetry: .init(
                stateOfCharge: .known(percent: 91),
                stateOfHealth: .known(percent: 99),
                dcBusRaw: 4_000,
                dcBusVolts: 400,
                currentRaw: 25,
                currentCandidateAmperes: 25,
                positiveBMS: bms,
                negativeBMS: bms,
                stateUpdatedAt: updatedAt,
                signalsUpdatedAt: updatedAt
            ),
            lastUpdated: updatedAt
        )
    }
}
