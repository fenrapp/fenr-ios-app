@testable import BikeData
import BikeDomain
import BikeSDK

func makeRepository(client: BikeTelemetryClient) -> LiveBikeRepository {
    LiveBikeRepository(
        client: client,
        eventHandler: makeEventHandler(),
        stateStore: .init(),
        telemetryHub: .init(bufferingPolicy: .unbounded),
        connectionHub: .init(bufferingPolicy: .unbounded),
        debugHub: .init(bufferingPolicy: .unbounded),
        batteryHealthStore: .init(),
        batteryHealthHub: .init(bufferingPolicy: .unbounded),
        batteryCaptureHub: .init(bufferingPolicy: .unbounded),
        discoveredBikesHub: .init(bufferingPolicy: .unbounded),
        chargePowerMapper: .init()
    )
}

private func makeEventHandler() -> LiveBikeRepositoryEventHandler {
    LiveBikeRepositoryEventHandler(
        telemetryMapper: .init(),
        eventMapper: .init(
            connectionMapper: .init(),
            connectionDebugMapper: .init(),
            notificationDebugMapper: .init()
        ),
        batteryHealthMapper: .init(),
        batteryDatasetMapper: .init(),
        connectionSessionPolicy: .init()
    )
}
