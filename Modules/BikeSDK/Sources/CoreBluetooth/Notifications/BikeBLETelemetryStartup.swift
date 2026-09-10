import CoreBluetooth

@MainActor
final class BikeBLETelemetryStartup {
    private let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let timeoutScheduler: any BikeBLETimeoutScheduling
    private let peripheralOperations: BikeBLEPeripheralOperations
    private var deadlineGeneration = 0
    private var didTimeOut = false

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        timeoutScheduler: any BikeBLETimeoutScheduling,
        peripheralOperations: BikeBLEPeripheralOperations
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.timeoutScheduler = timeoutScheduler
        self.peripheralOperations = peripheralOperations
    }

    func start() {
        reset()
        guard sessionStore.authenticationState == .authenticated,
              !sessionStore.hasReportedDashboardTelemetry else { return }
        scheduleDeadline(afterRetry: false)
    }

    func received(characteristicUUID: CBUUID) -> Bool {
        _ = sessionStore.markTelemetryReceived(
            characteristicUUID: characteristicUUID,
            requiredCharacteristicUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        )
        guard !didTimeOut, sessionStore.markDashboardTelemetryReady() else { return false }
        cancelDeadline()
        return true
    }

    func reset() {
        cancelDeadline()
        didTimeOut = false
    }

    private func cancelDeadline() {
        deadlineGeneration += 1
        timeoutScheduler.cancel()
    }

    private func scheduleDeadline(afterRetry: Bool) {
        cancelDeadline()
        let deadline = deadlineGeneration
        let session = sessionStore.generation
        timeoutScheduler.schedule { [weak self] in
            guard let self, self.deadlineGeneration == deadline, self.sessionStore.generation == session,
                  self.sessionStore.authenticationState == .authenticated,
                  !self.sessionStore.hasReportedDashboardTelemetry else { return }
            if afterRetry {
                self.didTimeOut = true
                let message = "Authenticated, but no dashboard telemetry was received. Try connecting again."
                await self.eventEmitter.send(.error(.operationFailed(message)))
                guard self.sessionStore.generation == session, self.deadlineGeneration == deadline else { return }
                await self.eventEmitter.send(.connection(.failed(message: message)))
                return
            }
            self.scheduleDeadline(afterRetry: true)
            guard let peripheral = self.sessionStore.peripheral else { return }
            for uuid in BikeSDKConstants.dashboardTelemetryUUIDs {
                guard self.sessionStore.generation == session, !self.sessionStore.hasReportedDashboardTelemetry,
                      let characteristic = self.sessionStore.discoveredCharacteristics[uuid],
                      characteristic.properties.contains(.read),
                      self.sessionStore.claimTelemetryRetry(for: uuid, operation: .read) else { continue }
                await self.peripheralOperations.readValue(characteristic: characteristic, peripheral: peripheral)
            }
        }
    }
}
