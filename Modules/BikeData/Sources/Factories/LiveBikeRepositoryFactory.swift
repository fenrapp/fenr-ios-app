import AsyncSupport
import BikeDomain
import BikeSDK
import Foundation

public enum LiveBikeRepositoryFactory {
    public static func makeDefault(
        client: BikeTelemetryClient,
        profileRepository: (any BikeProfileRepository)? = nil,
        diagnosticsEnabled: @escaping @Sendable () -> Bool = { false }
    ) -> LiveBikeRepository {
        let configuration = BikeRepositoryStreamConfiguration()
        let stateStore = BikeRepositoryStateStore()
        let telemetryHub = AsyncEventHub<BikeTelemetry>(
            bufferingPolicy: .bufferingNewest(configuration.telemetryBufferLimit)
        )
        return LiveBikeRepository(
            client: client,
            eventHandler: LiveBikeRepositoryEventHandler(
                telemetryMapper: BikeSDKTelemetryPayloadToDomainMapper(
                    powerCalculator: BikePowerTelemetryCalculator(),
                    maximumPowerInputSkew: Constants.maximumPowerInputSkew
                ),
                eventMapper: BikeSDKEventToDomainMapper(
                    connectionMapper: BikeSDKConnectionStatusToDomainMapper(),
                    connectionDebugMapper: BikeSDKConnectionStatusDebugMapper(),
                    notificationDebugMapper: BikeSDKNotificationDebugToDomainMapper()
                ),
                imuMapper: BikeSDKIMUSampleToDomainMapper(),
                imuRateLimiter: BikeIMUSampleRateLimiter(
                    minimumInterval: configuration.imuMinimumInterval
                ),
                batteryHealthMapper: BikeSDKTelemetryPayloadToBatteryHealthMapper(),
                batteryDatasetMapper: BikeSDKBatteryDatasetToDomainMapper(),
                connectionSessionPolicy: BikeConnectionSessionPolicy(),
                alphaEvidencePersistence: BikeAlphaEvidencePersistence(
                    profileRepository: profileRepository
                ),
                now: Date.init,
                diagnosticsEnabled: diagnosticsEnabled
            ),
            stateStore: stateStore, telemetryHub: telemetryHub,
            connectionHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.connectionBufferLimit)
            ),
            debugHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.debugBufferLimit)
            ),
            imuHub: AsyncEventHub(
                bufferingPolicy: .bufferingNewest(configuration.imuBufferLimit)
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
            controlService: LiveBikeControlService(
                client: client,
                chargePowerMapper: BikeSDKChargePowerControlToDomainMapper(),
                bikeLockMapper: BikeSDKBikeLockControlToDomainMapper(),
                advancedPowerModeMapper: BikeAdvancedPowerModeMapper()
            ),
            curveConfirmation: .init(stateStore: stateStore, telemetryHub: telemetryHub)
        )
    }

    public static func makePinDeriver() -> any BikePinDeriving {
        StarkBikePinDeriver()
    }

    private enum Constants {
        static let maximumPowerInputSkew: TimeInterval = 2
    }
}
