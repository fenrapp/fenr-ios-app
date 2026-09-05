import BLETraceDomain

public struct BikeBLEEventEmitter: Sendable {
    private let captureState: BLETraceCaptureState
    private let eventHub: AsyncEventHub<BikeSDKEvent>
    private let connectionStatusObserver: @Sendable (BikeSDKConnectionStatus) async -> Void

    public init(
        eventHub: AsyncEventHub<BikeSDKEvent>,
        captureState: BLETraceCaptureState,
        connectionStatusObserver: @escaping @Sendable (BikeSDKConnectionStatus) async -> Void
    ) {
        self.eventHub = eventHub
        self.captureState = captureState
        self.connectionStatusObserver = connectionStatusObserver
    }

    public var isRecordingDiagnostics: Bool { captureState.isRecording }

    public func sendDiagnostic(
        _ event: @autoclosure () -> BikeSDKEvent,
        isolation: isolated (any Actor)? = #isolation
    ) async {
        guard captureState.isRecording else { return }
        await eventHub.send(event())
    }

    public func send(_ event: BikeSDKEvent) async {
        await eventHub.send(event)
        if case .connection(let status) = event {
            await connectionStatusObserver(status)
        }
    }

    public func fail(_ error: BikeSDKError) async throws {
        await send(.error(error))
        throw error
    }
}
