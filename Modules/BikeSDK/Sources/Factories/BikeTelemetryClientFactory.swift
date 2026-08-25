import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
public enum BikeTelemetryClientFactory {
    public static func makeDefault() -> BikeTelemetryClient {
        makeDefault(
            centralRestorationIdentifier: CoreBluetoothRestorationPolicy.restorationIdentifier(for: .main),
            automaticallyRetryPairing: false,
            authenticationLinkRecoveryEnabled: false
        )
    }

    public static func makeDefault(
        centralRestorationIdentifier: String?,
        automaticallyRetryPairing: Bool = false,
        authenticationLinkRecoveryEnabled: Bool = false
    ) -> BikeTelemetryClient {
        let runtimeConfiguration = BikeSDKRuntimeConfiguration()
        let eventHub = makeEventHub(runtimeConfiguration: runtimeConfiguration)
        let eventEmitter = BikeBLEEventEmitter(eventHub: eventHub)
        let sessionStore = BLESessionStore()
        let adapter = AppleCoreBluetoothAdapter()
        let callbackQueue = BikeBLECallbackQueue()
        let notificationCoordinator = makeNotificationCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            runtimeConfiguration: runtimeConfiguration
        )
        let pairingRetryController = makePairingRetryController(
            adapter: adapter,
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            automaticallyRetryPairing: automaticallyRetryPairing,
            authenticationLinkRecoveryEnabled: authenticationLinkRecoveryEnabled
        )
        let securityCoordinator = makeSecurityCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            notificationCoordinator: notificationCoordinator,
            runtimeConfiguration: runtimeConfiguration,
            pairingRetryController: pairingRetryController
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
        let connectionCoordinator = makeConnectionCoordinator(
            .init(
                adapter: adapter,
                sessionStore: sessionStore,
                eventEmitter: eventEmitter,
                peripheralDelegate: peripheralDelegate,
                reconnectPolicy: runtimeConfiguration.reconnectPolicy
            ),
            notificationCoordinator: notificationCoordinator,
            securityCoordinator: securityCoordinator
        )
        let centralDelegate = makeCentralDelegate(connectionCoordinator, callbackQueue: callbackQueue)
        return makeClient(.init(
            eventHub: eventHub,
            adapter: adapter,
            callbackQueue: callbackQueue,
            connectionCoordinator: connectionCoordinator,
            securityCoordinator: securityCoordinator,
            notificationCoordinator: notificationCoordinator,
            centralDelegate: centralDelegate,
            centralRestorationIdentifier: centralRestorationIdentifier
        ))
    }

    private static func makeEventHub(
        runtimeConfiguration: BikeSDKRuntimeConfiguration
    ) -> AsyncEventHub<BikeSDKEvent> {
        AsyncEventHub(
            bufferingPolicy: .bufferingNewest(runtimeConfiguration.eventBufferLimit)
        )
    }

    private static func makeCentralDelegate(
        _ connectionCoordinator: BikeBLEConnectionCoordinator,
        callbackQueue: BikeBLECallbackQueue
    ) -> CoreBluetoothCentralDelegateProxy {
        CoreBluetoothCentralDelegateProxy(
            connectionCoordinator: connectionCoordinator,
            callbackQueue: callbackQueue
        )
    }

    private static func makeSecurityCoordinator(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationCoordinator: BikeBLENotificationCoordinator,
        runtimeConfiguration: BikeSDKRuntimeConfiguration,
        pairingRetryController: BikeBLEPairingRetryController?
    ) -> BikeBLESecurityCoordinator {
        let watchdog = BikeBLESecurityWatchdog(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            timeoutScheduler: BikeBLEOperationTimeoutScheduler(
                duration: runtimeConfiguration.securityOperationTimeout
            ),
            timeoutRecoveryHandler: { [pairingRetryController] in
                await pairingRetryController?.recoverIfNeeded()
            }
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
            handshake: handshake,
            pairingRetryController: pairingRetryController
        )
    }

    private static func makeConnectionCoordinator(
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
                reconnectDelay: BikeBLEReconnectDelay(),
                reconnectPolicy: input.reconnectPolicy
            ),
            sessionResetHandler: { [notificationCoordinator, securityCoordinator] in
                notificationCoordinator.resetSession()
                securityCoordinator.resetSession()
            }
        )
    }

    private struct ConnectionCoordinatorInput {
        let adapter: CoreBluetoothAdapter
        let sessionStore: BLESessionStore
        let eventEmitter: BikeBLEEventEmitter
        let peripheralDelegate: CBPeripheralDelegate
        let reconnectPolicy: BikeBLEReconnectPolicy
    }

    private static func makePairingRetryController(
        adapter: CoreBluetoothAdapter,
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        automaticallyRetryPairing: Bool,
        authenticationLinkRecoveryEnabled: Bool
    ) -> BikeBLEPairingRetryController? {
        guard automaticallyRetryPairing else { return nil }
        let recovery = BikeBLEAuthenticationLinkRecovery(
            adapter: adapter,
            sessionStore: sessionStore,
            eventEmitter: eventEmitter
        )
        let recoveryHandler: (@MainActor @Sendable () async -> Void)?
        if authenticationLinkRecoveryEnabled {
            recoveryHandler = { @MainActor in await recovery.restart() }
        } else {
            recoveryHandler = nil
        }
        return BikeBLEPairingRetryController(
            eventEmitter: eventEmitter,
            recoveryHandler: recoveryHandler,
            policy: BikeBLEPairingRetryPolicy(
                maximumAttempts: 3,
                delay: .seconds(3)
            )
        )
    }

    private struct CoreBluetoothClientComponents {
        let eventHub: AsyncEventHub<BikeSDKEvent>
        let adapter: CoreBluetoothAdapter
        let callbackQueue: BikeBLECallbackQueue
        let connectionCoordinator: BikeBLEConnectionCoordinator
        let securityCoordinator: BikeBLESecurityCoordinator
        let notificationCoordinator: BikeBLENotificationCoordinator
        let centralDelegate: CoreBluetoothCentralDelegateProxy
        let centralRestorationIdentifier: String?
    }

    private static func makeClient(
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

    private static func makeNotificationCoordinator(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        runtimeConfiguration: BikeSDKRuntimeConfiguration
    ) -> BikeBLENotificationCoordinator {
        let mapper = StarkNotificationToSDKEventMapper(
            decoderRegistry: BikeTelemetryDecoderRegistryFactory.make()
        )
        return BikeBLECoordinatorAssembly.makeNotificationCoordinator(
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

}
