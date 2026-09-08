@testable import BikeDiagnostics
import BLETraceDomain
import Foundation
import Observation
import Testing
import TestSupport

@MainActor
struct BikeDiagnosticsObservationTests {
    @Test("Export presentation independently invalidates when prepared and dismissed")
    func observesExportPresentation() async throws {
        let repository = FakeBLETraceLogRepository()
        let model = makeViewModel(repository: FakeBikeDiagnosticsRepository(), traceRepository: repository)
        let id = UUID()
        let prepared = ObservationChangeRecorder()
        withObservationTracking {
            _ = model.bleTraceExport
        } onChange: {
            prepared.record()
        }
        model.exportBLETraceSession(id: id)
        try #require(await waitUntil { model.bleTraceExport?.id == id })
        #expect(prepared.count == 1)
        #expect(await repository.exportedSessionIDs == [id])
        let dismissed = ObservationChangeRecorder()
        withObservationTracking {
            _ = model.bleTraceExport
        } onChange: {
            dismissed.record()
        }
        model.clearBLETraceExport()
        #expect(model.bleTraceExport == nil)
        #expect(dismissed.count == 1)
        await model.stopAndWait()
    }

    @Test("Capture state observed by the screen invalidates when a recording finishes")
    func observesCaptureCompletion() async throws {
        let repository = FakeBLETraceLogRepository()
        let model = makeViewModel(repository: FakeBikeDiagnosticsRepository(), traceRepository: repository)
        defer { model.setPresentationActive(false) }
        let id = UUID()
        model.setPresentationActive(true)
        await repository.send([BLETraceSessionSummary(
            id: id, startedAt: Date(timeIntervalSince1970: 10), endedAt: nil,
            duration: nil, fileSizeBytes: 1_024, eventCount: 2,
            status: .active, fileName: "fenr-observation-test.jsonl"
        )])
        try #require(await waitUntil { model.viewState.bleTraceSessions.first?.isActive == true })
        let recorder = ObservationChangeRecorder()
        withObservationTracking {
            _ = model.viewState.bleTraceSessions
        } onChange: {
            recorder.record()
        }
        await repository.send([BLETraceSessionSummary(
            id: id, startedAt: Date(timeIntervalSince1970: 10), endedAt: Date(timeIntervalSince1970: 20),
            duration: 10, fileSizeBytes: 2_048, eventCount: 4,
            status: .complete, fileName: "fenr-observation-test.jsonl"
        )])
        try #require(await waitUntil { model.viewState.bleTraceSessions.first?.canDelete == true })
        #expect(model.viewState.bleTraceSessions.first?.isActive == false)
        #expect(recorder.count == 1)
        await model.stopAndWait()
    }
}
