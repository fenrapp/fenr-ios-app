import CoreBluetooth

@MainActor
struct BikeBLEExperimentalCaptureCoordinator {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let notificationPreparer: BikeBLENotificationPreparer

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationPreparer: BikeBLENotificationPreparer
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.notificationPreparer = notificationPreparer
    }

    func start(peripheral: CBPeripheral) async {
        guard sessionStore.authenticationState == .authenticated,
              sessionStore.markExperimentalCaptureStarted()
        else {
            return
        }
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Starting experimental capture after baseline telemetry"
        )))
        for uuid in BikeSDKConstants.experimentalCaptureUUIDs {
            guard let characteristic = sessionStore.discoveredCharacteristics[uuid] else { continue }
            sessionStore.enqueueExperimentalCaptureCharacteristic(characteristic)
        }
        await processNext(peripheral: peripheral)
    }

    func advance(after uuid: CBUUID, peripheral: CBPeripheral) async {
        guard sessionStore.completeActiveExperimentalCaptureCharacteristic(matching: uuid) else { return }
        await processNext(peripheral: peripheral)
    }

    private func processNext(peripheral: CBPeripheral) async {
        guard let characteristic = sessionStore.startNextExperimentalCaptureCharacteristic() else { return }
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.subscriptionTitle,
            detail: "Preparing experimental capture " + characteristic.uuid.uuidString
        )))
        await notificationPreparer.prepare(characteristic: characteristic, peripheral: peripheral)
    }
}
