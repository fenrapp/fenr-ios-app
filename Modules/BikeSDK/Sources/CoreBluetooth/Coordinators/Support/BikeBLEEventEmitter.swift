public struct BikeBLEEventEmitter: Sendable {
    private let eventHub: AsyncEventHub<BikeSDKEvent>
    private let connectionStatusObserver: @Sendable (BikeSDKConnectionStatus) async -> Void

    public init(
        eventHub: AsyncEventHub<BikeSDKEvent>,
        connectionStatusObserver: @escaping @Sendable (BikeSDKConnectionStatus) async -> Void
    ) {
        self.eventHub = eventHub
        self.connectionStatusObserver = connectionStatusObserver
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
