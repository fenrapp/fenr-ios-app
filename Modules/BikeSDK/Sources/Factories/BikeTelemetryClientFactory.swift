import Foundation
import StarkProtocol

@MainActor
public enum BikeTelemetryClientFactory {
    public static func makeDefault() -> BikeTelemetryClient {
        let runtimeConfiguration = BikeSDKRuntimeConfiguration()
        let eventHub = AsyncEventHub<BikeSDKEvent>(
            bufferingPolicy: .bufferingNewest(runtimeConfiguration.eventBufferLimit)
        )
        let eventEmitter = BikeBLEEventEmitter(eventHub: eventHub)
        let sessionStore = BLESessionStore()
        let adapter = AppleCoreBluetoothAdapter()
        let callbackQueue = BikeBLECallbackQueue()
        let notificationCoordinator = makeNotificationCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            runtimeConfiguration: runtimeConfiguration
        )
        let securityCoordinator = BikeBLESecurityCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            payloadBuilder: StarkAuthenticationPayloadBuilder(),
            configuration: BikeSecurityConfiguration(pairingDate: StarkPinConstants.fallbackPairingDate),
            notificationCoordinator: notificationCoordinator,
            watchdog: BikeBLESecurityWatchdog(
                sessionStore: sessionStore,
                eventEmitter: eventEmitter,
                timeoutScheduler: BikeBLEOperationTimeoutScheduler(
                    duration: runtimeConfiguration.securityOperationTimeout
                )
            )
        )
        let discoveryCoordinator = BikeBLEDiscoveryCoordinator(
            eventEmitter: eventEmitter,
            securityCoordinator: securityCoordinator,
            notificationCoordinator: notificationCoordinator
        )
        let peripheralDelegate = CoreBluetoothPeripheralDelegateProxy(
            sessionStore: sessionStore,
            callbackQueue: callbackQueue,
            discoveryCoordinator: discoveryCoordinator,
            securityCoordinator: securityCoordinator,
            notificationCoordinator: notificationCoordinator
        )
        let connectionCoordinator = BikeBLEConnectionCoordinator(
            adapter: adapter,
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            peripheralDelegate: peripheralDelegate,
            reconnectDelay: BikeBLEReconnectDelay(),
            reconnectPolicy: runtimeConfiguration.reconnectPolicy
        )
        let centralDelegate = CoreBluetoothCentralDelegateProxy(
            connectionCoordinator: connectionCoordinator,
            callbackQueue: callbackQueue
        )
        return CoreBluetoothBikeTelemetryClient(
            eventHub: eventHub,
            adapter: adapter,
            callbackQueue: callbackQueue,
            connectionCoordinator: connectionCoordinator,
            securityCoordinator: securityCoordinator,
            notificationCoordinator: notificationCoordinator,
            centralDelegate: centralDelegate
        )
    }

    private static func makeNotificationCoordinator(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        runtimeConfiguration: BikeSDKRuntimeConfiguration
    ) -> BikeBLENotificationCoordinator {
        let mapper = StarkNotificationToSDKEventMapper(
            decoderRegistry: StarkNotificationDecoderRegistry(
                decoders: makeProtocolNotificationDecoders().merging(
                    makeLiveNotificationDecoders(),
                    uniquingKeysWith: { _, replacement in replacement }
                )
            )
        )
        return BikeBLENotificationCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            notificationProcessor: BikeBLENotificationProcessor(
                eventEmitter: eventEmitter,
                notificationMapper: mapper,
                debugSampler: BikeNotificationDebugSampler(
                    minimumInterval: runtimeConfiguration.notificationDebugMinimumInterval
                )
            ),
            timeoutScheduler: BikeBLEOperationTimeoutScheduler(
                duration: runtimeConfiguration.subscriptionOperationTimeout
            )
        )
    }

    private static func makeProtocolNotificationDecoders() -> [UUID: StarkNotificationDecoder] {
        [
            StarkUUIDs.batterySOC: .adapting(
                decoder: StarkBatteryDecoder(),
                transform: BikeSDKTelemetryPayload.battery
            ),
            StarkUUIDs.batteryCellVoltages: .adapting(
                decoder: StarkCellVoltagesDecoder(),
                transform: BikeSDKTelemetryPayload.cellVoltages
            ),
            StarkUUIDs.batteryTemperatures: .adapting(
                decoder: StarkBatteryTemperaturesDecoder(),
                transform: BikeSDKTelemetryPayload.batteryTemperatures
            ),
            StarkUUIDs.batteryBalancing: .adapting(
                decoder: StarkBatteryBalancingDecoder(),
                transform: BikeSDKTelemetryPayload.batteryBalancing
            ),
            StarkUUIDs.chargerData: .adapting(
                decoder: StarkChargerDecoder(),
                transform: BikeSDKTelemetryPayload.charger
            ),
            StarkUUIDs.bikeStatus: .adapting(
                decoder: StarkStatusDecoder(),
                transform: BikeSDKTelemetryPayload.status
            ),
            StarkUUIDs.vcuTelemetryTLV: .adapting(
                decoder: StarkVCUBrakeDecoder(),
                when: { $0.starts(with: StarkVCUBrakePayloadLayout.header) },
                transform: BikeSDKTelemetryPayload.vcuBrake
            )
        ]
    }

    private static func makeLiveNotificationDecoders() -> [UUID: StarkNotificationDecoder] {
        [
            StarkUUIDs.liveMap: .adapting(
                decoder: StarkMapDecoder(),
                transform: { .map($0.modeIndex) }
            ),
            StarkUUIDs.liveSpeed: .adapting(
                decoder: StarkSpeedDecoder(),
                transform: BikeSDKTelemetryPayload.speed
            ),
            StarkUUIDs.liveThrottle: .adapting(
                decoder: StarkThrottleDecoder(),
                transform: BikeSDKTelemetryPayload.throttle
            ),
            StarkUUIDs.liveIMU: .adapting(
                decoder: StarkIMUDecoder(),
                transform: BikeSDKTelemetryPayload.imu
            ),
            StarkUUIDs.liveTotals: .adapting(
                decoder: StarkLiveTotalsDecoder(),
                transform: BikeSDKTelemetryPayload.liveTotals
            ),
            StarkUUIDs.inverterTemperatures: .adapting(
                decoder: StarkInverterTemperaturesDecoder(),
                transform: BikeSDKTelemetryPayload.inverterTemperatures
            ),
            StarkUUIDs.vin: .adapting(decoder: StarkVINDecoder(), transform: { .vin($0.value) })
        ]
    }
}
