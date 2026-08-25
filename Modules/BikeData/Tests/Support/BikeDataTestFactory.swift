@testable import BikeData
import BikeDomain
import BikeSDK

func makeRepository(
    client: BikeTelemetryClient,
    profileRepository: (any BikeProfileRepository)? = nil
) -> LiveBikeRepository {
    LiveBikeRepository(
        client: client,
        eventHandler: makeEventHandler(profileRepository: profileRepository),
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

private func makeEventHandler(
    profileRepository: (any BikeProfileRepository)?
) -> LiveBikeRepositoryEventHandler {
    LiveBikeRepositoryEventHandler(
        telemetryMapper: .init(),
        eventMapper: .init(
            connectionMapper: .init(),
            connectionDebugMapper: .init(),
            notificationDebugMapper: .init()
        ),
        batteryHealthMapper: .init(),
        batteryDatasetMapper: .init(),
        connectionSessionPolicy: .init(),
        profileRepository: profileRepository
    )
}
