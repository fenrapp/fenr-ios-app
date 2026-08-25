import BikeDomain
import BikeSDK

public enum LiveBikeRepositoryFactory {
    public static func makeDefault(client: BikeTelemetryClient) -> LiveBikeRepository {
        let configuration = BikeRepositoryStreamConfiguration()
        return LiveBikeRepository(
            client: client,
            eventHandler: LiveBikeRepositoryEventHandler(
                telemetryMapper: BikeSDKTelemetryPayloadToDomainMapper(),
                eventMapper: BikeSDKEventToDomainMapper(
                    connectionMapper: BikeSDKConnectionStatusToDomainMapper(),
                    connectionDebugMapper: BikeSDKConnectionStatusDebugMapper(),
                    notificationDebugMapper: BikeSDKNotificationDebugToDomainMapper()
                ),
                batteryHealthMapper: BikeSDKTelemetryPayloadToBatteryHealthMapper(),
                batteryDatasetMapper: BikeSDKBatteryDatasetToDomainMapper(),
                connectionSessionPolicy: BikeConnectionSessionPolicy()
            ),
            stateStore: BikeRepositoryStateStore(),
            telemetryHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.telemetryBufferLimit)
            ),
            connectionHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.connectionBufferLimit)
            ),
            debugHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.debugBufferLimit)
            ),
            batteryHealthStore: BatteryHealthStateStore(),
            batteryHealthHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.batteryHealthBufferLimit)
            ),
            batteryCaptureHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.batteryCaptureBufferLimit)
            ),
            discoveredBikesHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.connectionBufferLimit)
            ),
            chargePowerMapper: BikeSDKChargePowerControlToDomainMapper()
        )
    }

    public static func makePinDeriver() -> any BikePinDeriving {
        StarkBikePinDeriver()
    }
}
