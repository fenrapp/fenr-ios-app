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
    }

    static func makeNotificationCoordinator(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationProcessor: BikeBLENotificationProcessor,
        timeoutScheduler: any BikeBLETimeoutScheduling
    ) -> BikeBLENotificationCoordinator {
        let notificationPreparer = BikeBLENotificationPreparer(eventEmitter: eventEmitter)
        let experimentalCaptureCoordinator = BikeBLEExperimentalCaptureCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            notificationPreparer: notificationPreparer
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
            queue: subscriptionQueue
        )
        let chargePowerCoordinator = BikeBLEChargePowerCoordinator(
            transport: BikeBLEChargePowerTransport(sessionStore: sessionStore)
        )
        return BikeBLENotificationCoordinator(
            sessionStore: sessionStore,
            eventEmitter: eventEmitter,
            notificationProcessor: notificationProcessor,
            subscriptionCoordinator: subscriptionCoordinator,
            chargePowerCoordinator: chargePowerCoordinator
        )
    }

    static func makeConnectionCoordinator(
        dependencies: ConnectionDependencies,
        sessionResetHandler: @escaping @MainActor () -> Void = {}
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
            sessionResetHandler: sessionResetHandler
        )
    }
}
