@testable import BikeDiagnostics
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
        viewModel.startObserving()
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
        #expect(viewModel.viewState.bleTraceSessions.first?.status == "Recording")
        #expect(viewModel.viewState.bleTraceSessions.first?.canDelete == false)

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
}
