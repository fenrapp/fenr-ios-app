@testable import BikeDiagnostics
import BikeDomain
import BLETraceDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("BikeDiagnostics BLE trace logs")
struct BikeDiagnosticsBLETraceTests {
    @Test("Maps sessions and prepares exports")
    func mapsAndExportsSessions() async {
        let bikeRepository = FakeBikeDiagnosticsRepository()
        let traceRepository = FakeBLETraceLogRepository()
        let viewModel = makeViewModel(
            repository: bikeRepository,
            traceRepository: traceRepository
        )
        let id = UUID()
        viewModel.setPresentationActive(true)
        await traceRepository.send([BLETraceSessionSummary(
            id: id,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: nil,
            duration: nil,
            fileSizeBytes: 2_048,
            eventCount: 3,
            status: .active,
            fileName: "fenr-test.jsonl"
        )])

        #expect(await waitUntil { viewModel.viewState.bleTraceSessions.count == 1 })
        #expect(viewModel.viewState.bleTraceSessions.first?.statusKind == .recording)
        #expect(viewModel.viewState.bleTraceSessions.first?.canDelete == false)
        #expect(viewModel.viewState.bleTraceSessions.first?.eventCount == "3")

        viewModel.exportBLETraceSession(id: id)
        #expect(await waitUntil { viewModel.bleTraceExport?.id == id })
        #expect(await traceRepository.exportedSessionIDs == [id])
    }

    @Test("Forwards individual and bulk deletion")
    func deletesSessions() async {
        let traceRepository = FakeBLETraceLogRepository()
        let viewModel = makeViewModel(
            repository: FakeBikeDiagnosticsRepository(),
            traceRepository: traceRepository
        )
        let id = UUID()

        viewModel.deleteBLETraceSession(id: id)
        #expect(await waitUntil { await traceRepository.deletedSessionIDs == [id] })
        viewModel.deleteAllBLETraceSessions()
        #expect(await waitUntil { await traceRepository.deleteAllCount == 1 })
    }

    @Test("Starts and stops captures only when the session allows it")
    func controlsCapture() async {
        let repository = FakeBikeDiagnosticsRepository()
        let vehicleSession = FakeVehicleSession(snapshot: .init(
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENR Test"))
        ))
        let traceRepository = FakeBLETraceLogRepository()
        let viewModel = makeViewModel(
            repository: repository,
            session: vehicleSession,
            traceRepository: traceRepository
        )
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { viewModel.viewState.isDisconnectEnabled })

        viewModel.toggleBLETraceCapture()
        #expect(await waitUntil { await repository.diagnosticsCaptureStartCount() == 1 })
        #expect(viewModel.viewState.isBLETraceCaptureControlInProgress)
        viewModel.toggleBLETraceCapture()
        #expect(await repository.diagnosticsCaptureStartCount() == 1)

        let id = UUID()
        await traceRepository.send([BLETraceSessionSummary(
            id: id,
            startedAt: Date(timeIntervalSince1970: 20),
            endedAt: nil,
            duration: nil,
            fileSizeBytes: 1_024,
            eventCount: 8,
            status: .active,
            fileName: "fenr-active-test.jsonl"
        )])
        #expect(await waitUntil {
            viewModel.viewState.bleTraceSessions.first?.isActive == true
                && !viewModel.viewState.isBLETraceCaptureControlInProgress
        })

        viewModel.toggleBLETraceCapture()
        #expect(await waitUntil { await repository.diagnosticsCaptureStopCount() == 1 })
        #expect(viewModel.viewState.isBLETraceCaptureControlInProgress)
        viewModel.toggleBLETraceCapture()
        #expect(await repository.diagnosticsCaptureStopCount() == 1)
        await traceRepository.send([BLETraceSessionSummary(
            id: id,
            startedAt: Date(timeIntervalSince1970: 20),
            endedAt: Date(timeIntervalSince1970: 30),
            duration: 10,
            fileSizeBytes: 1_024,
            eventCount: 8,
            status: .complete,
            fileName: "fenr-active-test.jsonl"
        )])
        #expect(await waitUntil { !viewModel.viewState.isBLETraceCaptureControlInProgress })
    }

    @Test("Capture control reports a timeout when the session stream never confirms")
    func captureControlTimesOutWithoutConfirmation() async {
        let repository = FakeBikeDiagnosticsRepository()
        let vehicleSession = FakeVehicleSession(snapshot: .init(
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENR Test"))
        ))
        let viewModel = makeViewModel(
            repository: repository,
            session: vehicleSession,
            bleTraceCaptureConfirmationTimeout: .milliseconds(20)
        )
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { viewModel.viewState.isDisconnectEnabled })

        viewModel.toggleBLETraceCapture()

        #expect(await waitUntil { viewModel.viewState.bleTraceError != nil })
        #expect(!viewModel.viewState.isBLETraceCaptureControlInProgress)
    }

    @Test("Leaving Diagnostics cancels capture confirmation without a stale error")
    func leavingDiagnosticsCancelsCaptureConfirmation() async {
        let repository = FakeBikeDiagnosticsRepository()
        let vehicleSession = FakeVehicleSession(snapshot: .init(
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENR Test"))
        ))
        let traceRepository = FakeBLETraceLogRepository()
        let viewModel = makeViewModel(
            repository: repository,
            session: vehicleSession,
            traceRepository: traceRepository,
            bleTraceCaptureConfirmationTimeout: .milliseconds(20)
        )
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { viewModel.viewState.isDisconnectEnabled })

        viewModel.toggleBLETraceCapture()
        #expect(await waitUntil { await repository.diagnosticsCaptureStartCount() == 1 })
        viewModel.setPresentationActive(false)
        let id = UUID()
        await traceRepository.send([BLETraceSessionSummary(
            id: id,
            startedAt: Date(timeIntervalSince1970: 20),
            endedAt: nil,
            duration: nil,
            fileSizeBytes: 1_024,
            eventCount: 1,
            status: .active,
            fileName: "fenr-replayed-test.jsonl"
        )])
        try? await Task.sleep(for: .milliseconds(30))

        #expect(viewModel.viewState.bleTraceError == nil)
        #expect(!viewModel.viewState.isBLETraceCaptureControlInProgress)
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { viewModel.viewState.bleTraceSessions.first?.id == id })
        #expect(viewModel.viewState.bleTraceError == nil)
    }
}
