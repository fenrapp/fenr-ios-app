import BLETraceDomain
import Foundation

/// Optional diagnostic collaborators for the emulator; recordings contain synthetic events only.
public struct BikeEmulatorDiagnostics: Sendable {
    let recorder: any BLETraceRecording
    let captureState: BLETraceCaptureState
    let uptimeNanoseconds: @Sendable () -> UInt64

    public init(
        recorder: any BLETraceRecording,
        captureState: BLETraceCaptureState,
        uptimeNanoseconds: @escaping @Sendable () -> UInt64
    ) {
        self.recorder = recorder
        self.captureState = captureState
        self.uptimeNanoseconds = uptimeNanoseconds
    }
}
