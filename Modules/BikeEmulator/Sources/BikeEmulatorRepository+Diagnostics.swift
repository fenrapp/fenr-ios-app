import BLETraceDomain
import Foundation

extension BikeEmulatorRepository {
    public func startNewDiagnosticsCapture(vin: String) async -> Bool {
        guard vin == configuration.vin,
              lifecycleState == .started,
              diagnosticsStartTask == nil,
              diagnosticsStopTask == nil,
              !diagnostics.captureState.isRecording
        else { return false }
        diagnosticsGeneration &+= 1
        let operationGeneration = diagnosticsGeneration
        let date = await runtime.now()
        guard operationGeneration == diagnosticsGeneration, !Task.isCancelled else { return false }
        let context = BLETraceSessionContext(
            id: UUID(), startedAt: date,
            startUptimeNanoseconds: diagnostics.uptimeNanoseconds(), reason: .manualRequest
        )
        let recorder = diagnostics.recorder
        let task = Task { await recorder.startSession(context) }
        diagnosticsStartTask = task
        let started = await task.value
        guard operationGeneration == diagnosticsGeneration else { return false }
        diagnosticsStartTask = nil
        guard started, !Task.isCancelled else {
            await recorder.finishSession(reason: .clientStopped)
            return false
        }
        diagnostics.captureState.setRecording(true)
        await recorder.record(BLETraceEvent(
            timestamp: date, uptimeNanoseconds: diagnostics.uptimeNanoseconds(),
            category: "emulator", operation: .sessionStarted, direction: .internalEvent,
            detail: "Synthetic emulator capture; no physical Bluetooth traffic"
        ))
        return diagnostics.captureState.isRecording && operationGeneration == diagnosticsGeneration
    }

    public func stopDiagnosticsCapture() async -> Bool {
        if let diagnosticsStopTask {
            return await diagnosticsStopTask.value
        }
        diagnosticsGeneration &+= 1
        diagnostics.captureState.setRecording(false)
        let startingTask = diagnosticsStartTask
        startingTask?.cancel()
        let recorder = diagnostics.recorder
        // Teardown owns this task and awaits it even when the initiating UI operation is cancelled.
        let stoppingTask = Task {
            _ = await startingTask?.value
            return await recorder.finishSession(reason: .userStopped)
        }
        diagnosticsStopTask = stoppingTask
        let succeeded = await stoppingTask.value
        await captureHub.reset()
        diagnosticsStartTask = nil
        diagnosticsStopTask = nil
        return succeeded
    }
}
