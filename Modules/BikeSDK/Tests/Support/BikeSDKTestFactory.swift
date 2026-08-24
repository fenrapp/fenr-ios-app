@testable import BikeSDK
import CoreBluetooth
import Foundation
import RuntimeConfiguration
import StarkProtocol

@MainActor
func makeConnectionCoordinator(
    adapter: CoreBluetoothAdapter,
    eventHub: AsyncEventHub<BikeSDKEvent>,
    sessionResetHandler: @escaping @MainActor () -> Void = {}
) -> BikeBLEConnectionCoordinator {
    BikeBLECoordinatorAssembly.makeConnectionCoordinator(
        dependencies: .init(
            adapter: adapter,
            sessionStore: BLESessionStore(),
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
            peripheralDelegate: NoOpPeripheralDelegate(),
            reconnectDelay: BikeBLEReconnectDelay(),
            reconnectPolicy: .init(delays: [.zero])
        ),
        sessionResetHandler: sessionResetHandler
    )
}

func makeNotificationMapper() -> StarkNotificationToSDKEventMapper {
    let registry = StarkNotificationDecoderRegistry(decoders: makeProtocolNotificationDecoders().merging(
        makeLiveNotificationDecoders(),
        uniquingKeysWith: { _, replacement in replacement }
    ))
    return StarkNotificationToSDKEventMapper(decoderRegistry: registry)
}

private func makeProtocolNotificationDecoders() -> [UUID: StarkNotificationDecoder] {
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
            when: { data in
                data.starts(with: StarkVCUBrakePayloadLayout.header)
            },
            transform: BikeSDKTelemetryPayload.vcuBrake
        )
    ]
}

private func makeLiveNotificationDecoders() -> [UUID: StarkNotificationDecoder] {
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
        StarkUUIDs.vin: .adapting(
            decoder: StarkVINDecoder(),
            transform: { .vin($0.value) }
        )
    ]
}

func makeMutableCharacteristic(uuid: UUID) -> CBMutableCharacteristic {
    CBMutableCharacteristic(
        type: CBUUID(nsuuid: uuid),
        properties: [.notify],
        value: nil,
        permissions: []
    )
}

@MainActor
func makeNotificationCoordinator(
    sessionStore: BLESessionStore,
    eventHub: AsyncEventHub<BikeSDKEvent>,
    timeoutScheduler: any BikeBLETimeoutScheduling
) -> BikeBLENotificationCoordinator {
    let eventEmitter = BikeBLEEventEmitter(eventHub: eventHub)
    return BikeBLECoordinatorAssembly.makeNotificationCoordinator(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        notificationProcessor: BikeBLENotificationProcessor(
            eventEmitter: eventEmitter,
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 1)
        ),
        timeoutScheduler: timeoutScheduler
    )
}

@MainActor
func makeTelemetryClient(
    adapter: CoreBluetoothAdapter,
    eventHub: AsyncEventHub<BikeSDKEvent>
) -> CoreBluetoothBikeTelemetryClient {
    let sessionStore = BLESessionStore()
    let eventEmitter = BikeBLEEventEmitter(eventHub: eventHub)
    let callbackQueue = BikeBLECallbackQueue()
    let runtimeConfiguration = BikeSDKRuntimeConfiguration()
    let notificationCoordinator = BikeBLECoordinatorAssembly.makeNotificationCoordinator(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        notificationProcessor: BikeBLENotificationProcessor(
            eventEmitter: eventEmitter,
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 1)
        ),
        timeoutScheduler: BikeBLEOperationTimeoutScheduler(
            duration: runtimeConfiguration.subscriptionOperationTimeout
        )
    )
    let securityCoordinator = makeSecurityCoordinator(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        notificationCoordinator: notificationCoordinator,
        runtimeConfiguration: runtimeConfiguration
    )
    let coordinator = BikeBLECoordinatorAssembly.makeConnectionCoordinator(
        dependencies: .init(
            adapter: adapter,
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            peripheralDelegate: NoOpPeripheralDelegate(),
            reconnectDelay: BikeBLEReconnectDelay(),
            reconnectPolicy: .init(delays: [.zero])
        ),
        sessionResetHandler: { [notificationCoordinator] in
            notificationCoordinator.resetSession()
        }
    )
    return CoreBluetoothBikeTelemetryClient(
        eventHub: eventHub,
        adapter: adapter,
        callbackQueue: callbackQueue,
        connectionCoordinator: coordinator,
        securityCoordinator: securityCoordinator,
        notificationCoordinator: notificationCoordinator,
        centralDelegate: CoreBluetoothCentralDelegateProxy(
            connectionCoordinator: coordinator,
            callbackQueue: callbackQueue
        ),
        centralRestorationIdentifier: FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
    )
}

@MainActor
private func makeSecurityCoordinator(
    sessionStore: BLESessionStore,
    eventEmitter: BikeBLEEventEmitter,
    notificationCoordinator: BikeBLENotificationCoordinator,
    runtimeConfiguration: BikeSDKRuntimeConfiguration
) -> BikeBLESecurityCoordinator {
    let watchdog = BikeBLESecurityWatchdog(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        timeoutScheduler: BikeBLEOperationTimeoutScheduler(
            duration: runtimeConfiguration.securityOperationTimeout
        )
    )
    let handshake = BikeBLESecurityHandshake(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        payloadBuilder: StarkAuthenticationPayloadBuilder(),
        configuration: BikeSecurityConfiguration(pairingDate: StarkPinConstants.fallbackPairingDate),
        notificationCoordinator: notificationCoordinator,
        watchdog: watchdog
    )
    return BikeBLESecurityCoordinator(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        watchdog: watchdog,
        handshake: handshake
    )
}
