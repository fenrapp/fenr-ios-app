@testable import BikeDiagnostics
import BikeDomain
import Foundation
import MeasurementPresentation
import Testing
import TestSupport
import VehicleSession

@MainActor
@Suite("BikeDiagnostics")
struct BikeDiagnosticsTests {
    @Test("Destination family is stable and complete")
    func destinationFamily() {
        #expect(BikeDiagnosticsDestination.allCases == [
            .overview, .connection, .telemetry, .status, .events, .bleLogs
        ])
        #expect(Set(BikeDiagnosticsDestination.allCases.map(\.title)).count == 6)
    }

    @Test("New presentation copy resolves through the module catalog")
    func localizedPresentationCopy() {
        #expect(BikeDiagnosticsDestination.overview.title == "Diagnostics")
        #expect(BikeDiagnosticsDestination.bleLogs.title == "BLE Logs")
        #expect(DiagnosticsCopy.batteryHealthDetail == "Cells, temperature, charging and raw data")
        #expect(DiagnosticsCopy.eventsExportFooter.contains("600 events"))
        #expect(BikeDiagnosticsMetricViewData.Verification.candidate.title == "Candidate")
        #expect(BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricMap(5)) == "Map 5")
        #expect(BikeDiagnosticsL10n.text(.bikeDiagnosticsValueAttention(2)) == "Attention (2)")
    }

    @Test("Presentation lifecycle observes once and never owns the shared session")
    func presentationLifecycle() async {
        let session = FakeVehicleSession()
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository, session: session)

        #expect(await session.observeCount == 0)
        viewModel.setPresentationActive(true)
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { await session.observeCount == 1 })

        viewModel.setPresentationActive(false)
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { await session.observeCount == 2 })
        #expect(await session.startCount == 0)
        #expect(await session.stopCount == 0)
        #expect(await repository.startCount() == 0)
        #expect(await repository.stopCount() == 0)
    }

    @Test("Unified snapshot maps identity, connection and the complete telemetry surface")
    func mapsUnifiedSnapshot() async {
        let session = FakeVehicleSession()
        let viewModel = makeViewModel(
            repository: FakeBikeDiagnosticsRepository(),
            session: session
        )
        viewModel.setPresentationActive(true)
        await session.send(fullSnapshot())
        #expect(await waitUntil { viewModel.viewState.vin == "FENRTEST000000001" })

        #expect(viewModel.viewState.connection.rssi == "-58 dBm")
        #expect(viewModel.viewState.connection.peripheralName == "FENR Bike")
        #expect(viewModel.viewState.connection.peripheralIdentifier != "--")
        #expect(viewModel.viewState.overviewMetrics.map(\.id) == [
            "mode", "speed", "electricalPower", "battery", "soh", "alerts"
        ])
        #expect(viewModel.viewState.telemetrySections.map(\.id) == [
            "vehicle", "live", "power", "battery", "temperatures", "configurations", "powerTier"
        ])
        #expect(metric("odometer", in: viewModel.viewState).value.contains("123"))
        #expect(metric("inverterTemperature0", in: viewModel.viewState).value.contains("31"))
        #expect(metric("configuration0", in: viewModel.viewState).value.contains("62 hp"))
        #expect(metric("powerTierEvidence", in: viewModel.viewState).value.contains("Power above standard"))
    }

    @Test("Candidates are explicit while confirmed values remain confirmed")
    func candidateLabels() async {
        let session = FakeVehicleSession()
        let viewModel = makeViewModel(
            repository: FakeBikeDiagnosticsRepository(),
            session: session
        )
        viewModel.setPresentationActive(true)
        await session.send(fullSnapshot())
        #expect(await waitUntil { !viewModel.viewState.batteryMetrics.isEmpty })

        #expect(viewModel.viewState.batteryMetrics.first { $0.id == "batteryCurrent" }?.verification == .candidate)
        #expect(
            viewModel.viewState.batteryMetrics
                .first { $0.id == "positiveVoltageCandidate" }?.verification == .candidate
        )
        #expect(viewModel.viewState.batteryMetrics.first { $0.id == "batteryDcBus" }?.verification == .confirmed)
    }

    @Test("Decoded status is paired with every original bitfield")
    func mapsStatusAndRawFlags() async {
        let session = FakeVehicleSession()
        let viewModel = makeViewModel(
            repository: FakeBikeDiagnosticsRepository(),
            session: session
        )
        viewModel.setPresentationActive(true)
        await session.send(fullSnapshot())
        #expect(await waitUntil { viewModel.viewState.decodedStatus.first?.value == "On" })

        #expect(viewModel.viewState.decodedStatus.contains { $0.id == "fault" && $0.value == "Yes" })
        #expect(viewModel.viewState.decodedStatus.contains { $0.id == "leftBlinker" && $0.value == "Yes" })
        #expect(viewModel.viewState.rawFlags.map(\.id) == ["misc", "indicator", "alert", "fault", "info"])
        #expect(viewModel.viewState.rawFlags.first { $0.id == "fault" }?.value == "0x0002")
    }

    @Test("Explicit actions use configured identity and shared-session refresh")
    func actions() async {
        let repository = FakeBikeDiagnosticsRepository()
        let session = FakeVehicleSession()
        let viewModel = makeViewModel(repository: repository, session: session)
        viewModel.setPresentationActive(true)
        await session.send(fullSnapshot(connection: .init(state: .disconnected(reason: nil))))
        #expect(await waitUntil { viewModel.viewState.isReconnectEnabled })

        viewModel.reconnectTapped()
        #expect(await waitUntil { await repository.connectedVIN() == "FENRTEST000000001" })
        viewModel.pairRetryTapped()
        #expect(await waitUntil { await repository.didRetrySecurityHandshake() })
        viewModel.disconnectTapped()
        #expect(await waitUntil { await repository.didDisconnect() })
        viewModel.readSnapshotTapped()
        #expect(await waitUntil { await session.refreshCount == 1 })
    }

    @Test("Visible events coalesce to 30 while export preserves 600")
    func eventLimitsAndExport() async {
        let repository = FakeBikeDiagnosticsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.setPresentationActive(true)
        let repeatedID = UUID()
        for index in 0..<605 {
            await repository.sendDebugEvent(.init(
                id: index < 2 ? repeatedID : UUID(),
                title: "Notification",
                detail: "Packet \(index)"
            ))
        }
        #expect(await waitUntil { viewModel.viewState.debugEvents.first?.detail == "Packet 604" })

        let eventLines = viewModel.debugLogText()
            .components(separatedBy: BikeDiagnosticsConstants.debugLogLineSeparator)
            .filter { $0.contains(" | Notification | ") }
        #expect(viewModel.viewState.debugEvents.count == 30)
        #expect(eventLines.count == 600)
        #expect(viewModel.debugLogText().contains("[Decoded Status]"))
        #expect(viewModel.debugLogText().contains("[Raw Status]"))

        viewModel.clearDebugEvents()
        #expect(viewModel.viewState.debugEvents.isEmpty)
    }

    private func metric(
        _ id: String,
        in state: BikeDiagnosticsViewState
    ) -> BikeDiagnosticsMetricViewData {
        state.telemetrySections
            .flatMap(\.metrics)
            .first(where: { $0.id == id })!
    }

}
