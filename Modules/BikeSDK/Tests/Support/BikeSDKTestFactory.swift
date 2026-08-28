@testable import BikeSDK
import BLETraceDomain
import CoreBluetooth
import Foundation
import RuntimeConfiguration
import StarkProtocol

@MainActor
func makeConnectionCoordinator(
    adapter: CoreBluetoothAdapter,
    eventHub: AsyncEventHub<BikeSDKEvent>,
    connectionTimeoutScheduler: any BikeBLETimeoutScheduling = FakeBikeBLETimeoutScheduler(),
    sessionResetHandler: @escaping @MainActor () -> Void = {}
) -> BikeBLEConnectionCoordinator {
    let traceEmitter = makeTraceEmitter()
    let reconnectController = BikeBLEReconnectController(
        delay: BikeBLEReconnectDelay(),
        policy: .init(delays: [.zero]),
        connectionStabilityPeriod: .zero
    )
    return BikeBLECoordinatorAssembly.makeConnectionCoordinator(
        dependencies: .init(
            adapter: adapter,
            sessionStore: BLESessionStore(),
            eventEmitter: makeEventEmitter(eventHub: eventHub),
            peripheralDelegate: NoOpPeripheralDelegate(),
            reconnectController: reconnectController,
            connectionWatchdog: BikeBLEConnectionWatchdog(
                timeoutScheduler: connectionTimeoutScheduler
            ),
            traceEmitter: traceEmitter,
            peripheralOperations: BikeBLEPeripheralOperations(traceEmitter: traceEmitter)
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

@MainActor
func makeTraceEmitter(recorder: any BLETraceRecording = NoOpBLETraceRepository())
    -> BikeBLETraceEmitter {
    BikeBLETraceEmitter(
        recorder: recorder,
        now: Date.init,
        uptimeNanoseconds: { DispatchTime.now().uptimeNanoseconds },
        makeSessionID: UUID.init
    )
}

func makeEventEmitter(eventHub: AsyncEventHub<BikeSDKEvent>) -> BikeBLEEventEmitter {
    BikeBLEEventEmitter(eventHub: eventHub, connectionStatusObserver: { _ in })
}

private func makeProtocolNotificationDecoders() -> [UUID: StarkNotificationDecoder] {
    [
        StarkUUIDs.batterySOC: .adapting(
            decoder: StarkBatteryDecoder(),
            transform: BikeSDKTelemetryPayload.battery
        ),
        StarkUUIDs.batteryParams: .adapting(
            decoder: StarkBatteryParametersDecoder(),
            transform: BikeSDKTelemetryPayload.batteryParameters
        ),
        StarkUUIDs.batterySignals: .adapting(
            decoder: StarkBatterySignalsDecoder(),
            transform: BikeSDKTelemetryPayload.batterySignals
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
        StarkUUIDs.liveEstimation: .adapting(
            decoder: StarkLiveEstimationsDecoder(),
            transform: BikeSDKTelemetryPayload.liveEstimations
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
    makeNotificationCoordinator(
        sessionStore: sessionStore,
        eventHub: eventHub,
        timeoutScheduler: timeoutScheduler,
        connectionDidBecomeReady: {}
    )
}

@MainActor
private func makeNotificationCoordinator(
    sessionStore: BLESessionStore,
    eventHub: AsyncEventHub<BikeSDKEvent>,
    timeoutScheduler: any BikeBLETimeoutScheduling,
    connectionDidBecomeReady: @escaping @MainActor () -> Void
) -> BikeBLENotificationCoordinator {
    let eventEmitter = makeEventEmitter(eventHub: eventHub)
    let traceEmitter = makeTraceEmitter()
    return BikeBLECoordinatorAssembly.makeNotificationCoordinator(dependencies: .init(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        notificationProcessor: BikeBLENotificationProcessor(
            eventEmitter: eventEmitter,
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 1),
            traceEmitter: traceEmitter
        ),
        timeoutScheduler: timeoutScheduler,
        connectionDidBecomeReady: connectionDidBecomeReady,
        peripheralOperations: BikeBLEPeripheralOperations(traceEmitter: traceEmitter)
    ))
}

@MainActor
func makeTelemetryClient(
    adapter: CoreBluetoothAdapter,
    eventHub: AsyncEventHub<BikeSDKEvent>
) -> CoreBluetoothBikeTelemetryClient {
    let sessionStore = BLESessionStore()
    let eventEmitter = makeEventEmitter(eventHub: eventHub)
    let callbackQueue = BikeBLECallbackQueue()
    let runtimeConfiguration = BikeSDKRuntimeConfiguration()
    let traceEmitter = makeTraceEmitter()
    let peripheralOperations = BikeBLEPeripheralOperations(traceEmitter: traceEmitter)
    let reconnectController = BikeBLEReconnectController(
        delay: BikeBLEReconnectDelay(),
        policy: .init(delays: [.zero]),
        connectionStabilityPeriod: .zero
    )
    let notificationCoordinator = makeNotificationCoordinator(
        sessionStore: sessionStore,
        eventHub: eventHub,
        timeoutScheduler: BikeBLEOperationTimeoutScheduler(
            duration: runtimeConfiguration.subscriptionOperationTimeout
        ),
        connectionDidBecomeReady: reconnectController.markConnectionReady
    )
    let securityCoordinator = makeSecurityCoordinator(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        notificationCoordinator: notificationCoordinator,
        runtimeConfiguration: runtimeConfiguration,
        peripheralOperations: peripheralOperations
    )
    let coordinator = BikeBLECoordinatorAssembly.makeConnectionCoordinator(
        dependencies: .init(
            adapter: adapter,
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            peripheralDelegate: NoOpPeripheralDelegate(),
            reconnectController: reconnectController,
            connectionWatchdog: makeConnectionWatchdog(
                duration: runtimeConfiguration.connectionOperationTimeout
            ),
            traceEmitter: traceEmitter,
            peripheralOperations: peripheralOperations
        ),
        sessionResetHandler: { [notificationCoordinator, securityCoordinator] in
            notificationCoordinator.resetSession()
            securityCoordinator.resetSession()
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
            callbackQueue: callbackQueue,
            traceEmitter: traceEmitter
        ),
        centralRestorationIdentifier: FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
    )
}

@MainActor
private func makeConnectionWatchdog(duration: Duration) -> BikeBLEConnectionWatchdog {
    BikeBLEConnectionWatchdog(
        timeoutScheduler: BikeBLEOperationTimeoutScheduler(duration: duration)
    )
}

@MainActor
private func makeSecurityCoordinator(
    sessionStore: BLESessionStore,
    eventEmitter: BikeBLEEventEmitter,
    notificationCoordinator: BikeBLENotificationCoordinator,
    runtimeConfiguration: BikeSDKRuntimeConfiguration,
    peripheralOperations: BikeBLEPeripheralOperations
) -> BikeBLESecurityCoordinator {
    let watchdog = BikeBLESecurityWatchdog(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        timeoutScheduler: BikeBLEOperationTimeoutScheduler(
            duration: runtimeConfiguration.securityOperationTimeout
        ),
        timeoutRecoveryHandler: {}
    )
    let handshake = BikeBLESecurityHandshake(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        payloadBuilder: StarkAuthenticationPayloadBuilder(),
        configuration: BikeSecurityConfiguration(pairingDate: StarkPinConstants.fallbackPairingDate),
        notificationCoordinator: notificationCoordinator,
        watchdog: watchdog,
        peripheralOperations: peripheralOperations
    )
    return BikeBLESecurityCoordinator(
        sessionStore: sessionStore,
        eventEmitter: eventEmitter,
        watchdog: watchdog,
        handshake: handshake,
        pairingRetryController: nil,
        peripheralOperations: peripheralOperations
    )
}
