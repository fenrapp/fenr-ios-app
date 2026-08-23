import BikeData
import BikeDomain
import BikeSDK

struct BikeDataDependencyContainer {
    func makeBikePinDeriver() -> any BikePinDeriving {
        StarkBikePinDeriver()
    }

    func makeBikeRepository(client: BikeTelemetryClient) -> LiveBikeRepository {
        let streamConfiguration = BikeRepositoryStreamConfiguration()
        return LiveBikeRepository(
            client: client,
            eventHandler: makeRepositoryEventHandler(),
            stateStore: BikeRepositoryStateStore(),
            telemetryHub: BikeData.AsyncEventHub<BikeTelemetry>(
                bufferingPolicy: .bufferingNewest(streamConfiguration.telemetryBufferLimit)
            ),
            connectionHub: BikeData.AsyncEventHub<BikeConnection>(
                bufferingPolicy: .bufferingNewest(streamConfiguration.connectionBufferLimit)
            ),
            debugHub: BikeData.AsyncEventHub<BikeDebugEvent>(
                bufferingPolicy: .bufferingNewest(streamConfiguration.debugBufferLimit)
            ),
            batteryHealthStore: BatteryHealthStateStore(),
            batteryHealthHub: BikeData.AsyncEventHub<BikeBatteryHealth>(
                bufferingPolicy: .bufferingNewest(streamConfiguration.batteryHealthBufferLimit)
            ),
            batteryCaptureHub: BikeData.AsyncEventHub<BatteryDatasetCapture>(
                bufferingPolicy: .bufferingNewest(streamConfiguration.batteryCaptureBufferLimit)
            ),
            discoveredBikesHub: BikeData.AsyncEventHub<[DiscoveredBike]>(
                bufferingPolicy: .bufferingNewest(streamConfiguration.connectionBufferLimit)
            )
        )
    }

    private func makeRepositoryEventHandler() -> LiveBikeRepositoryEventHandler {
        LiveBikeRepositoryEventHandler(
            telemetryMapper: BikeSDKTelemetryPayloadToDomainMapper(),
            eventMapper: BikeSDKEventToDomainMapper(
                connectionMapper: BikeSDKConnectionStatusToDomainMapper(),
                connectionDebugMapper: BikeSDKConnectionStatusDebugMapper(),
                notificationDebugMapper: BikeSDKNotificationDebugToDomainMapper()
            ),
            batteryHealthMapper: BikeSDKTelemetryPayloadToBatteryHealthMapper(),
            batteryDatasetMapper: BikeSDKBatteryDatasetToDomainMapper(),
            connectionSessionPolicy: BikeConnectionSessionPolicy()
        )
    }
}
