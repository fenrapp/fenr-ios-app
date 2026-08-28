import BikeSDK
import BLETraceDomain
import RuntimeConfiguration

@MainActor
struct BikeSDKDependencyContainer {
    func makeBikeTelemetryClient(traceRecorder: any BLETraceRecording) -> BikeTelemetryClient {
        BikeTelemetryClientFactory.makeDefault(
            traceRecorder: traceRecorder,
            centralRestorationIdentifier: FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
        )
    }
}
