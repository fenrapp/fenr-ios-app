@testable import BikeSDK

@MainActor
func makeUserTractionCoordinator(
        _ transport: FakeBikeBLEPowerModeConfigurationTransport
    ) -> BikeBLEPowerModeConfigurationCoordinator {
        .init(transport: transport, eventEmitter: makeEventEmitter(eventHub: .init(bufferingPolicy: .unbounded)))
    }
