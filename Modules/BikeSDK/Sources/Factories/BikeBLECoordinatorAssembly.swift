import CoreBluetooth

@MainActor
enum BikeBLECoordinatorAssembly {
    struct ConnectionDependencies {
        let adapter: CoreBluetoothAdapter
        let sessionStore: BLESessionStore
        let eventEmitter: BikeBLEEventEmitter
        let peripheralDelegate: CBPeripheralDelegate
        let reconnectDelay: any BikeBLEReconnectDelaying
        let reconnectPolicy: BikeBLEReconnectPolicy
        let connectionWatchdog: BikeBLEConnectionWatchdog
    }

    static func makeNotificationCoordinator(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationProcessor: BikeBLENotificationProcessor,
        timeoutScheduler: any BikeBLETimeoutScheduling
    ) -> BikeBLENotificationCoordinator {
        let notificationPreparer = BikeBLENotificationPreparer(eventEmitter: eventEmitter)
        let configurationTransport = BikeBLEVCUConfigurationTransport(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter
        )
        let experimentalCaptureCoordinator = BikeBLEExperimentalCaptureCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            notificationPreparer: notificationPreparer
        )
        let powerModeCoordinator = BikeBLEPowerModeConfigurationCoordinator(
            transport: configurationTransport,
            eventEmitter: eventEmitter,
            sessionStore: sessionStore
        )
        let subscriptionQueue = BikeBLESubscriptionQueue(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            timeoutScheduler: timeoutScheduler,
            experimentalCaptureCoordinator: experimentalCaptureCoordinator
        )
        let subscriptionCoordinator = BikeBLESubscriptionCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            notificationPreparer: notificationPreparer,
            experimentalCaptureCoordinator: experimentalCaptureCoordinator,
            queue: subscriptionQueue,
            requiredSubscriptionsDidComplete: {
                powerModeCoordinator.startAutomaticRefreshIfNeeded()
            },
            configSubscriptionDidComplete: {
                powerModeCoordinator.startAutomaticRefreshIfNeeded()
            }
        )
        let chargePowerCoordinator = BikeBLEChargePowerCoordinator(
            transport: configurationTransport
        )
        return BikeBLENotificationCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            notificationProcessor: notificationProcessor,
            subscriptionCoordinator: subscriptionCoordinator,
            chargePowerCoordinator: chargePowerCoordinator,
            powerModeCoordinator: powerModeCoordinator,
            configurationTransport: configurationTransport
        )
    }

    static func makeConnectionCoordinator(
        dependencies: ConnectionDependencies,
        sessionResetHandler: @escaping @MainActor () -> Void
    ) -> BikeBLEConnectionCoordinator {
        let reconnectController = BikeBLEReconnectController(
            delay: dependencies.reconnectDelay,
            policy: dependencies.reconnectPolicy
        )
        let scanner = BikeBLEConnectionScanner(
            adapter: dependencies.adapter,
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            peripheralDelegate: dependencies.peripheralDelegate,
            reconnectController: reconnectController
        )
        return BikeBLEConnectionCoordinator(
            adapter: dependencies.adapter,
            sessionStore: dependencies.sessionStore,
            eventEmitter: dependencies.eventEmitter,
            peripheralDelegate: dependencies.peripheralDelegate,
            reconnectController: reconnectController,
            scanner: scanner,
            connectionErrorClassifier: BikeBLEConnectionErrorClassifier(),
            connectionWatchdog: dependencies.connectionWatchdog,
            sessionResetHandler: sessionResetHandler
        )
    }
}
