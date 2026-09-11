import BLETraceDomain
import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
public enum BikeTelemetryClientFactory {
    public static func makeDefault(
        traceRecorder: any BLETraceRecording,
        captureState: BLETraceCaptureState,
        centralRestorationIdentifier: String?,
        automaticallyRetryPairing: Bool = false,
        authenticationLinkRecoveryEnabled: Bool = false
    ) -> BikeTelemetryClient {
        let context = makeContext(traceRecorder: traceRecorder, captureState: captureState)
        let notificationCoordinator = makeNotificationCoordinator(context)
        let pairingRetryController = makePairingRetryController(
            context,
            automaticallyRetryPairing: automaticallyRetryPairing,
            authenticationLinkRecoveryEnabled: authenticationLinkRecoveryEnabled
        )
        let securityCoordinator = makeSecurityCoordinator(
            context,
            notificationCoordinator: notificationCoordinator,
            pairingRetryController: pairingRetryController
        )
        let discoveryCoordinator = BikeBLEDiscoveryCoordinator(
            eventEmitter: context.eventEmitter,
            securityCoordinator: securityCoordinator,
            notificationCoordinator: notificationCoordinator,
            peripheralOperations: context.peripheralOperations
        )
        let peripheralDelegate = CoreBluetoothPeripheralDelegateProxy(
            sessionStore: context.sessionStore,
            callbackQueue: context.callbackQueue,
            discoveryCoordinator: discoveryCoordinator,
            securityCoordinator: securityCoordinator,
            notificationCoordinator: notificationCoordinator,
            traceEmitter: context.traceEmitter
        )
        let connectionCoordinator = makeConnectionCoordinator(
            .init(
                adapter: context.adapter,
                sessionStore: context.sessionStore,
                eventEmitter: context.eventEmitter,
                peripheralDelegate: peripheralDelegate,
                reconnectController: context.reconnectController,
                connectionWatchdog: BikeBLEConnectionWatchdog(
                    timeoutScheduler: BikeBLEOperationTimeoutScheduler(
                        duration: context.runtimeConfiguration.connectionOperationTimeout
                    )
                ),
                traceEmitter: context.traceEmitter,
                peripheralOperations: context.peripheralOperations
            ),
            notificationCoordinator: notificationCoordinator,
            securityCoordinator: securityCoordinator
        )
        let centralDelegate = makeCentralDelegate(
            connectionCoordinator,
            callbackQueue: context.callbackQueue,
            traceEmitter: context.traceEmitter
        )
        return makeClient(.init(
            eventHub: context.eventHub,
            adapter: context.adapter,
            callbackQueue: context.callbackQueue,
            connectionCoordinator: connectionCoordinator,
            securityCoordinator: securityCoordinator,
            notificationCoordinator: notificationCoordinator,
            centralDelegate: centralDelegate,
            centralRestorationIdentifier: centralRestorationIdentifier
        ))
    }

}

private extension BikeTelemetryClientFactory {
    struct FactoryContext {
        let captureState: BLETraceCaptureState
        let runtimeConfiguration: BikeSDKRuntimeConfiguration
        let eventHub: AsyncEventHub<BikeSDKEvent>
        let eventEmitter: BikeBLEEventEmitter
        let sessionStore: BLESessionStore
        let adapter: CoreBluetoothAdapter
        let callbackQueue: BikeBLECallbackQueue
        let reconnectController: BikeBLEReconnectController
        let traceEmitter: BikeBLETraceEmitter
        let peripheralOperations: BikeBLEPeripheralOperations
    }

    static func makeContext(
        traceRecorder: any BLETraceRecording,
        captureState: BLETraceCaptureState
    ) -> FactoryContext {
        let runtimeConfiguration = BikeSDKRuntimeConfiguration()
        let eventHub = makeEventHub(runtimeConfiguration: runtimeConfiguration)
        let traceEmitter = BikeBLETraceEmitter(
            recorder: traceRecorder,
            captureState: captureState,
            now: Date.init,
            uptimeNanoseconds: { DispatchTime.now().uptimeNanoseconds },
            makeSessionID: UUID.init
        )
        let reconnectController = BikeBLEReconnectController(
            delay: BikeBLEReconnectDelay(),
            policy: runtimeConfiguration.reconnectPolicy,
            connectionStabilityPeriod: runtimeConfiguration.connectionStabilityPeriod
        )
        return FactoryContext(
            captureState: captureState,
            runtimeConfiguration: runtimeConfiguration,
            eventHub: eventHub,
            eventEmitter: BikeBLEEventEmitter(
                eventHub: eventHub,
                captureState: captureState,
                connectionStatusObserver: { [traceEmitter] status in
                    await traceEmitter.recordConnectionState(status)
                }
            ),
            sessionStore: BLESessionStore(),
            adapter: AppleCoreBluetoothAdapter(),
            callbackQueue: BikeBLECallbackQueue(),
            reconnectController: reconnectController,
            traceEmitter: traceEmitter,
            peripheralOperations: BikeBLEPeripheralOperations(traceEmitter: traceEmitter)
        )
    }

    static func makeEventHub(
        runtimeConfiguration: BikeSDKRuntimeConfiguration
    ) -> AsyncEventHub<BikeSDKEvent> {
        AsyncEventHub(
            bufferingPolicy: .bufferingNewest(runtimeConfiguration.eventBufferLimit)
        )
    }

    static func makeCentralDelegate(
        _ connectionCoordinator: BikeBLEConnectionCoordinator,
        callbackQueue: BikeBLECallbackQueue,
        traceEmitter: BikeBLETraceEmitter
    ) -> CoreBluetoothCentralDelegateProxy {
        CoreBluetoothCentralDelegateProxy(
            connectionCoordinator: connectionCoordinator,
            callbackQueue: callbackQueue,
            traceEmitter: traceEmitter
        )
    }

    static func makeSecurityCoordinator(
        _ context: FactoryContext,
        notificationCoordinator: BikeBLENotificationCoordinator,
        pairingRetryController: BikeBLEPairingRetryController?
    ) -> BikeBLESecurityCoordinator {
        let watchdog = BikeBLESecurityWatchdog(
            sessionStore: context.sessionStore,
            eventEmitter: context.eventEmitter,
            timeoutScheduler: BikeBLEOperationTimeoutScheduler(
                duration: context.runtimeConfiguration.securityOperationTimeout
            ),
            timeoutRecoveryHandler: { [pairingRetryController] in
                await pairingRetryController?.recoverIfNeeded()
            }
        )
        let handshake = BikeBLESecurityHandshake(
            sessionStore: context.sessionStore,
            eventEmitter: context.eventEmitter,
            payloadBuilder: StarkAuthenticationPayloadBuilder(),
            configuration: BikeSecurityConfiguration(pairingDate: StarkPinConstants.fallbackPairingDate),
            notificationCoordinator: notificationCoordinator,
            watchdog: watchdog,
            peripheralOperations: context.peripheralOperations
        )
        return BikeBLESecurityCoordinator(
            sessionStore: context.sessionStore,
            eventEmitter: context.eventEmitter,
            watchdog: watchdog,
            handshake: handshake,
            pairingRetryController: pairingRetryController,
            peripheralOperations: context.peripheralOperations
        )
    }

    static func makeConnectionCoordinator(
        _ input: ConnectionCoordinatorInput,
        notificationCoordinator: BikeBLENotificationCoordinator,
        securityCoordinator: BikeBLESecurityCoordinator
    ) -> BikeBLEConnectionCoordinator {
        BikeBLECoordinatorAssembly.makeConnectionCoordinator(
            dependencies: .init(
                adapter: input.adapter,
                sessionStore: input.sessionStore,
                eventEmitter: input.eventEmitter,
                peripheralDelegate: input.peripheralDelegate,
                reconnectController: input.reconnectController,
                connectionWatchdog: input.connectionWatchdog,
                traceEmitter: input.traceEmitter,
                peripheralOperations: input.peripheralOperations
            ),
            sessionResetHandler: { [notificationCoordinator, securityCoordinator] in
                notificationCoordinator.resetSession()
                securityCoordinator.resetSession()
            }
        )
    }

    struct ConnectionCoordinatorInput {
        let adapter: CoreBluetoothAdapter
        let sessionStore: BLESessionStore
        let eventEmitter: BikeBLEEventEmitter
        let peripheralDelegate: CBPeripheralDelegate
        let reconnectController: BikeBLEReconnectController
        let connectionWatchdog: BikeBLEConnectionWatchdog
        let traceEmitter: BikeBLETraceEmitter
        let peripheralOperations: BikeBLEPeripheralOperations
    }

    static func makePairingRetryController(
        _ context: FactoryContext,
        automaticallyRetryPairing: Bool,
        authenticationLinkRecoveryEnabled: Bool
    ) -> BikeBLEPairingRetryController? {
        guard automaticallyRetryPairing else { return nil }
        let recovery = BikeBLEAuthenticationLinkRecovery(
            adapter: context.adapter,
            sessionStore: context.sessionStore,
            eventEmitter: context.eventEmitter,
            traceEmitter: context.traceEmitter
        )
        let recoveryHandler: (@MainActor @Sendable () async -> Void)?
        if authenticationLinkRecoveryEnabled {
            recoveryHandler = { @MainActor in await recovery.restart() }
        } else {
            recoveryHandler = nil
        }
        return BikeBLEPairingRetryController(
            eventEmitter: context.eventEmitter,
            recoveryHandler: recoveryHandler,
            policy: BikeBLEPairingRetryPolicy(
                maximumAttempts: 3,
                delay: .seconds(3)
            )
        )
    }

    struct CoreBluetoothClientComponents {
        let eventHub: AsyncEventHub<BikeSDKEvent>
        let adapter: CoreBluetoothAdapter
        let callbackQueue: BikeBLECallbackQueue
        let connectionCoordinator: BikeBLEConnectionCoordinator
        let securityCoordinator: BikeBLESecurityCoordinator
        let notificationCoordinator: BikeBLENotificationCoordinator
        let centralDelegate: CoreBluetoothCentralDelegateProxy
        let centralRestorationIdentifier: String?
    }

    static func makeClient(
        _ components: CoreBluetoothClientComponents
    ) -> CoreBluetoothBikeTelemetryClient {
        CoreBluetoothBikeTelemetryClient(
            eventHub: components.eventHub,
            adapter: components.adapter,
            callbackQueue: components.callbackQueue,
            connectionCoordinator: components.connectionCoordinator,
            securityCoordinator: components.securityCoordinator,
            notificationCoordinator: components.notificationCoordinator,
            centralDelegate: components.centralDelegate,
            centralRestorationIdentifier: components.centralRestorationIdentifier
        )
    }

    static func makeNotificationCoordinator(_ context: FactoryContext) -> BikeBLENotificationCoordinator {
        let mapper = StarkNotificationToSDKEventMapper(
            decoderRegistry: BikeTelemetryDecoderRegistryFactory.make()
        )
        return BikeBLECoordinatorAssembly.makeNotificationCoordinator(dependencies: .init(
            captureState: context.captureState,
            sessionStore: context.sessionStore,
            eventEmitter: context.eventEmitter,
            notificationProcessor: BikeBLENotificationProcessor(
                eventEmitter: context.eventEmitter,
                notificationMapper: mapper,
                debugSampler: BikeNotificationDebugSampler(
                    minimumInterval: context.runtimeConfiguration.notificationDebugMinimumInterval
                ),
                traceEmitter: context.traceEmitter
            ),
            timeoutScheduler: BikeBLEOperationTimeoutScheduler(
                duration: context.runtimeConfiguration.subscriptionOperationTimeout
            ),
            telemetryStartupScheduler: BikeBLEOperationTimeoutScheduler(duration: .seconds(15)),
            connectionDidBecomeReady: context.reconnectController.markConnectionReady,
            peripheralOperations: context.peripheralOperations
        ))
    }
}
