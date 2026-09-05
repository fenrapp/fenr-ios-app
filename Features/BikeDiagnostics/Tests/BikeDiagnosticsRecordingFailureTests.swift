@testable import BikeDiagnostics
import BLETraceDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Diagnostic recording failures")
struct BikeDiagnosticsRecordingFailureTests {
    @Test("An unavailable history has its own recoverable error")
    func unavailableHistory() async {
        let repository = FakeBLETraceLogRepository()
        await repository.sendFailure(.init(sessionID: nil, phase: .preparing))
        let viewModel = makeViewModel(repository: FakeBikeDiagnosticsRepository(), traceRepository: repository)
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { viewModel.viewState.bleTraceError != nil })
        #expect(viewModel.viewState.bleTraceError == BikeDiagnosticsL10n.text(.bikeDiagnosticsBleLogLoadError))
        await repository.sendFailure(nil)
        #expect(await waitUntil { viewModel.viewState.bleTraceError == nil })
        await viewModel.stopAndWait()
    }

    @Test("A writer failure is shown when diagnostics opens and survives unrelated actions", arguments: [
        BLETraceRecordingFailure.Phase.opening, .writing, .finishing
    ])
    func replaysWriterFailure(phase: BLETraceRecordingFailure.Phase) async {
        let traceRepository = FakeBLETraceLogRepository()
        await traceRepository.sendFailure(.init(sessionID: UUID(), phase: phase))
        let viewModel = makeViewModel(
            repository: FakeBikeDiagnosticsRepository(), traceRepository: traceRepository
        )
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { viewModel.viewState.bleTraceError != nil })
        let message = viewModel.viewState.bleTraceError
        #expect(message == BikeDiagnosticsL10n.text(.bikeDiagnosticsBleRecordingWriteError))
        #expect(!viewModel.viewState.bleTraceSessions.contains { $0.statusKind == .recording })

        let exportID = UUID()
        viewModel.exportBLETraceSession(id: exportID)
        #expect(await waitUntil { viewModel.bleTraceExport?.id == exportID })
        #expect(viewModel.viewState.bleTraceError == message)
        viewModel.setPresentationActive(false)
        viewModel.setPresentationActive(true)
        #expect(viewModel.viewState.bleTraceError == message)

        await traceRepository.sendFailure(nil)
        #expect(await waitUntil { viewModel.viewState.bleTraceError == nil })
        await viewModel.stopAndWait()
    }
}
