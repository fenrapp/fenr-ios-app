@testable import BikeSDK

@MainActor
func makeTelemetryStartup(
    store: BLESessionStore,
    eventHub: AsyncEventHub<BikeSDKEvent>,
    scheduler: FakeBikeBLETimeoutScheduler
) -> BikeBLETelemetryStartup {
    BikeBLETelemetryStartup(
        sessionStore: store,
        eventEmitter: makeEventEmitter(eventHub: eventHub),
        timeoutScheduler: scheduler,
        peripheralOperations: BikeBLEPeripheralOperations(traceEmitter: makeTraceEmitter())
    )
}
