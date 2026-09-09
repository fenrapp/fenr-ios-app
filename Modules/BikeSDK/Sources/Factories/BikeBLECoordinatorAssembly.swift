import BLETraceDomain
import CoreBluetooth

@MainActor
enum BikeBLECoordinatorAssembly {
    struct ConnectionDependencies {
        let adapter: CoreBluetoothAdapter
        let sessionStore: BLESessionStore
        let eventEmitter: BikeBLEEventEmitter
        let peripheralDelegate: CBPeripheralDelegate
        let reconnectController: BikeBLEReconnectController
        let connectionWatchdog: BikeBLEConnectionWatchdog
        let traceEmitter: BikeBLETraceEmitter
        let peripheralOperations: BikeBLEPeripheralOperations
    }

    struct NotificationDependencies {
        let captureState: BLETraceCaptureState
        let sessionStore: BLESessionStore
        let eventEmitter: BikeBLEEventEmitter
        let notificationProcessor: BikeBLENotificationProcessor
        let timeoutScheduler: any BikeBLETimeoutScheduling
        let connectionDidBecomeReady: @MainActor () -> Void
        let peripheralOperations: BikeBLEPeripheralOperations
    }

    static func makeNotificationCoordinator(
        dependencies: NotificationDependencies
    ) -> BikeBLENotificationCoordinator {
        let notificationPreparer = BikeBLENotificationPreparer(
            eventEmitter: dependencies.eventEmitter,
            peripheralOperations: dependencies.peripheralOperations
        )
        let configurationTransport = makeConfigurationTransport(dependencies)
        let experimentalCaptureCoordinator = BikeBLEExperimentalCaptureCoordinator(
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            notificationPreparer: notificationPreparer
        )
        let powerModeCoordinator = BikeBLEPowerModeConfigurationCoordinator(
            transport: configurationTransport,
            eventEmitter: dependencies.eventEmitter
        )
        let bikeLockCoordinator = BikeBLEBikeLockConfigurationCoordinator(
            transport: configurationTransport,
            eventEmitter: dependencies.eventEmitter
        )
        let subscriptionQueue = BikeBLESubscriptionQueue(
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            timeoutScheduler: dependencies.timeoutScheduler,
            experimentalCaptureCoordinator: experimentalCaptureCoordinator,
            peripheralOperations: dependencies.peripheralOperations
        )
        let subscriptionCoordinator = BikeBLESubscriptionCoordinator(
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            notificationPreparer: notificationPreparer,
            experimentalCaptureCoordinator: experimentalCaptureCoordinator,
            queue: subscriptionQueue
        )
        let chargePowerCoordinator = BikeBLEChargePowerCoordinator(
            transport: configurationTransport,
            verificationWaiter: BikeBLEChargePowerVerificationWaiter(),
            captureState: dependencies.captureState
        )
        return BikeBLENotificationCoordinator(
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            notificationProcessor: dependencies.notificationProcessor,
            subscriptionCoordinator: subscriptionCoordinator,
            chargePowerCoordinator: chargePowerCoordinator,
            powerModeCoordinator: powerModeCoordinator,
            advancedPowerModeCoordinator: .init(
                transport: configurationTransport, eventEmitter: dependencies.eventEmitter
            ),
            configurationSequenceGate: BikeBLEVCUConfigurationTransactionGate(),
            bikeLockCoordinator: bikeLockCoordinator,
            configurationTransport: configurationTransport,
            connectionDidBecomeReady: dependencies.connectionDidBecomeReady,
            peripheralOperations: dependencies.peripheralOperations
        )
    }

    private static func makeConfigurationTransport(
        _ dependencies: NotificationDependencies
    ) -> BikeBLEVCUConfigurationTransport {
        let transactionGate = BikeBLEVCUConfigurationTransactionGate()
        return BikeBLEVCUConfigurationTransport(
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            peripheralOperations: dependencies.peripheralOperations,
            configurationReadinessWaiter: .init(
                checkInterval: .milliseconds(50),
                maximumCheckCount: 100
            ),
            transactionGate: transactionGate,
            operationController: .init(timeoutScheduler: BikeBLEOperationTimeoutScheduler(duration: .seconds(5)))
        )
    }

    static func makeConnectionCoordinator(
        dependencies: ConnectionDependencies,
        sessionResetHandler: @escaping @MainActor () -> Void
    ) -> BikeBLEConnectionCoordinator {
        let scanner = BikeBLEConnectionScanner(
            adapter: dependencies.adapter,
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            peripheralDelegate: dependencies.peripheralDelegate,
            reconnectController: dependencies.reconnectController,
            traceEmitter: dependencies.traceEmitter,
            peripheralOperations: dependencies.peripheralOperations
        )
        return BikeBLEConnectionCoordinator(
            adapter: dependencies.adapter,
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            peripheralDelegate: dependencies.peripheralDelegate,
            reconnectController: dependencies.reconnectController,
            scanner: scanner,
            connectionErrorClassifier: BikeBLEConnectionErrorClassifier(),
            connectionWatchdog: dependencies.connectionWatchdog,
            sessionResetHandler: sessionResetHandler,
            traceEmitter: dependencies.traceEmitter,
            peripheralOperations: dependencies.peripheralOperations
        )
    }
}
