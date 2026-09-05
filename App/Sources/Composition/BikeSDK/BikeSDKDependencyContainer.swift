import BikeSDK
import BLETraceDomain
import RuntimeConfiguration

@MainActor
struct BikeSDKDependencyContainer {
    func makeBikeTelemetryClient(
        traceRecorder: any BLETraceRecording,
        captureState: BLETraceCaptureState
    ) -> BikeTelemetryClient {
        BikeTelemetryClientFactory.makeDefault(
            traceRecorder: traceRecorder,
            captureState: captureState,
            centralRestorationIdentifier: FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
        )
    }
}
