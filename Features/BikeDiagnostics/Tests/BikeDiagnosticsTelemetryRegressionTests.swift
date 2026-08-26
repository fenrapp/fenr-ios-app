@testable import BikeDiagnostics
import BikeDomain
import Foundation
import MeasurementPresentation
import Testing
import TestSupport

@MainActor
@Suite("BikeDiagnostics telemetry regressions")
struct BikeDiagnosticsTelemetryRegressionTests {
    @Test("SOC and run state follow the latest telemetry")
    func telemetryUpdatesSOCAndRunState() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { await repository.telemetryObserverCount() > 0 })

        await repository.sendTelemetry(telemetry(soc: 76, isOn: true))
        #expect(await waitUntil {
            viewModel.viewState.badges.contains("On")
        })
        await repository.sendTelemetry(telemetry(soc: 75, isOn: false))
        #expect(await waitUntil {
            viewModel.viewState.badges.contains("Off")
        })

        #expect(viewModel.viewState.metrics.contains(
            BikeDiagnosticsMetricViewData(
                id: "battery",
                title: "Battery",
                value: formattedPercent(75)
            )
        ))
        #expect(viewModel.viewState.badges == ["Off"])
    }

    @Test("Repeated characteristic events share one timeline row and remain exportable")
    func repeatedCharacteristicEventsAreCoalesced() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        let characteristic = UUID()
        let eventCount = 3
        viewModel.start()

        for index in 0..<eventCount {
            await repository.sendDebugEvent(.init(
                id: characteristic,
                title: "Notification",
                detail: "Packet \(index)"
            ))
        }
        #expect(await waitUntil {
            viewModel.viewState.debugEvents.first?.detail == "Packet 2"
        })

        let exportedLog = viewModel.debugLogText()
        let exportedLines = exportedLog
            .components(separatedBy: BikeDiagnosticsConstants.debugLogLineSeparator)
        #expect(viewModel.viewState.debugEvents.count == 1)
        #expect(exportedLog.contains("[Power Telemetry]"))
        #expect(exportedLog.contains("[Battery Telemetry]"))
        #expect(exportedLines.filter { $0.contains(" | Notification | ") }.count == eventCount)
        #expect(exportedLines.contains { $0.contains("Packet 2") })
    }

    private func telemetry(soc: Int, isOn: Bool) -> BikeTelemetry {
        BikeTelemetry(
            batteryLevel: .known(percent: soc),
            statusFlags: .init(isOn: isOn, isInGear: isOn),
            lastUpdated: Date()
        )
    }

    private func formattedPercent(_ value: Int) -> String {
        VehicleMeasurementTextFormatter(locale: .init(identifier: "es_ES")).percentage(value)
    }
}
