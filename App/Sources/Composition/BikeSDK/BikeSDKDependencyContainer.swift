import BikeSDK

@MainActor
struct BikeSDKDependencyContainer {
    func makeBikeTelemetryClient() -> BikeTelemetryClient {
        BikeTelemetryClientFactory.makeDefault()
    }
}
