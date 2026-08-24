public struct BikeBLEEventEmitter: Sendable {
    private let eventHub: AsyncEventHub<BikeSDKEvent>

    public init(eventHub: AsyncEventHub<BikeSDKEvent>) {
        self.eventHub = eventHub
    }

    public func send(_ event: BikeSDKEvent) async {
        await eventHub.send(event)
    }

    public func fail(_ error: BikeSDKError) async throws {
        await send(.error(error))
        throw error
    }
}
