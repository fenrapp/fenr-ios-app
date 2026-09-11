import CoreBluetooth
import Foundation

@MainActor
public struct BikeBLENotificationCoordinator {
    let sessionStore: BLESessionStore
    let eventEmitter: BikeBLEEventEmitter
    private let telemetryStartup: BikeBLETelemetryStartup
    private let notificationProcessor: BikeBLENotificationProcessor
    private let subscriptionCoordinator: BikeBLESubscriptionCoordinator
    let chargePowerCoordinator: BikeBLEChargePowerCoordinator
    let advancedPowerModeCoordinator: BikeBLEAdvancedPowerModeCoordinator
    let configurationSequenceGate: BikeBLEVCUConfigurationTransactionGate
    let powerModeCoordinator: BikeBLEPowerModeConfigurationCoordinator
    let bikeLockCoordinator: BikeBLEBikeLockConfigurationCoordinator
    private let configurationTransport: BikeBLEVCUConfigurationTransport
    private let connectionDidBecomeReady: @MainActor () -> Void
    private let peripheralOperations: BikeBLEPeripheralOperations

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationProcessor: BikeBLENotificationProcessor,
        telemetryStartup: BikeBLETelemetryStartup,
        subscriptionCoordinator: BikeBLESubscriptionCoordinator,
        chargePowerCoordinator: BikeBLEChargePowerCoordinator,
        powerModeCoordinator: BikeBLEPowerModeConfigurationCoordinator,
        advancedPowerModeCoordinator: BikeBLEAdvancedPowerModeCoordinator,
        configurationSequenceGate: BikeBLEVCUConfigurationTransactionGate,
        bikeLockCoordinator: BikeBLEBikeLockConfigurationCoordinator,
        configurationTransport: BikeBLEVCUConfigurationTransport,
        connectionDidBecomeReady: @escaping @MainActor () -> Void,
        peripheralOperations: BikeBLEPeripheralOperations
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.telemetryStartup = telemetryStartup
        self.notificationProcessor = notificationProcessor
        self.subscriptionCoordinator = subscriptionCoordinator
        self.chargePowerCoordinator = chargePowerCoordinator
        self.powerModeCoordinator = powerModeCoordinator
        self.advancedPowerModeCoordinator = advancedPowerModeCoordinator
        self.configurationSequenceGate = configurationSequenceGate
        self.bikeLockCoordinator = bikeLockCoordinator
        self.configurationTransport = configurationTransport
        self.connectionDidBecomeReady = connectionDidBecomeReady
        self.peripheralOperations = peripheralOperations
    }

    public func discovered(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        sessionStore.setCharacteristic(characteristic)
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: BikeSDKText.characteristicTitle,
            detail: "\(characteristic.uuid.uuidString) \(characteristic.properties.protocolDescription)"
        )))
        await subscriptionCoordinator.prepareIfNeeded(
            characteristic: characteristic,
            peripheral: peripheral
        )
        if sessionStore.authenticationState == .authenticated,
           BikeSDKConstants.telemetryCharacteristicUUIDs.contains(characteristic.uuid),
           characteristic.properties.contains(.read) {
            await peripheralOperations.readValue(characteristic: characteristic, peripheral: peripheral)
        }
    }

    public func didDiscoverDescriptors(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        await subscriptionCoordinator.didDiscoverDescriptors(
            peripheral: peripheral,
            characteristic: characteristic,
            error: error
        )
    }

    public func didUpdateNotificationState(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        error: Error?
    ) async {
        await subscriptionCoordinator.didUpdateNotificationState(
            peripheral: peripheral,
            characteristic: characteristic,
            error: error
        )
    }

    public func didUpdateValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) async {
        let characteristicUUIDString = characteristic.uuid.uuidString
        if configurationTransport.completeReadIfNeeded(characteristic: characteristic, error: error) {
            return
        }
        let generation = sessionStore.generation
        if let error {
            let message = "Value update failed \(characteristicUUIDString): \(error.localizedDescription)"
            await eventEmitter.send(.error(.operationFailed(message)))
            if sessionStore.generation == generation, sessionStore.authenticationState == .authenticated,
               characteristic.properties.contains(.read),
               sessionStore.claimTelemetryRetry(for: characteristic.uuid, operation: .read) {
                await peripheralOperations.readValue(characteristic: characteristic, peripheral: peripheral)
            }
            return
        }
        guard let data = characteristic.value else { return }
        let uuid = characteristic.uuid.foundationUUID
        let date = Date()
        if sessionStore.isBatteryHealthMonitoringActive(),
           let dataset = BikeSDKConstants.batteryDataset(for: characteristic.uuid) {
            await eventEmitter.sendDiagnostic(.batteryDatasetCapture(.init(
                dataset: dataset,
                byteCount: data.count,
                hex: data.bikeSDKHexString,
                date: date
            )))
        }
        let didDecodeTelemetry = await notificationProcessor.process(characteristic: uuid, data: data, date: date)
        guard sessionStore.generation == generation, didDecodeTelemetry else { return }
        if telemetryStartup.received(characteristicUUID: characteristic.uuid) {
            connectionDidBecomeReady()
            await eventEmitter.send(.connection(.receivingTelemetry(
                peripheralName: sessionStore.authenticatedConnectionName(fallback: peripheral.name)
            )))
        }
    }

    public func didReadRSSI(_ rssi: Int, error: Error?) async {
        guard error == nil else { return }
        await eventEmitter.send(.rssi(rssi))
    }

    public func authenticationDidSucceed(peripheral: CBPeripheral) async {
        telemetryStartup.start()
        notificationProcessor.resetDebugSampling()
        await subscriptionCoordinator.authenticationDidSucceed(peripheral: peripheral)
        await readAvailableTelemetrySnapshot(peripheral: peripheral, logsEveryRead: false)
    }

    public func startBatteryHealthMonitoring() async throws {
        try await subscriptionCoordinator.startBatteryHealthMonitoring()
        try await readAvailableBatteryHealthSnapshot()
    }

    public func startIMUMonitoring() async throws {
        try await subscriptionCoordinator.startIMUMonitoring()
    }

    public func stopIMUMonitoring() async {
        await subscriptionCoordinator.stopIMUMonitoring()
    }

    public func stopBatteryHealthMonitoring() async {
        await subscriptionCoordinator.stopBatteryHealthMonitoring()
    }

    public func didWriteValue(characteristic: CBCharacteristic, error: Error?) async {
        configurationTransport.completeWriteIfNeeded(characteristic: characteristic, error: error)
    }

    public func resetSession() {
        telemetryStartup.reset()
        subscriptionCoordinator.reset()
        chargePowerCoordinator.reset()
        powerModeCoordinator.reset()
        advancedPowerModeCoordinator.reset()
        bikeLockCoordinator.reset()
        configurationTransport.reset()
    }

    public func readTelemetrySnapshot() async throws {
        let peripheral = try await requirePeripheralForRead()
        guard await readAvailableTelemetrySnapshot(peripheral: peripheral, logsEveryRead: true) else {
            try await failRead(BikeSDKText.noReadableCharacteristics)
        }
    }

    public func readBikeStatusSnapshot() async throws {
        try await readSnapshot(characteristicUUID: BikeSDKConstants.bikeStatusCharacteristicUUID)
    }

    private func readSnapshot(characteristicUUID: CBUUID) async throws {
        let peripheral = try await requirePeripheralForRead()
        guard let characteristic = sessionStore.discoveredCharacteristics[characteristicUUID],
              characteristic.properties.contains(.read)
        else {
            try await failRead(BikeSDKText.noReadableCharacteristics)
        }
        await peripheralOperations.readValue(characteristic: characteristic, peripheral: peripheral)
    }

    private func readAvailableBatteryHealthSnapshot() async throws {
        let peripheral = try await requirePeripheralForRead()
        let characteristics = BikeSDKConstants.batteryHealthMonitoringUUIDs.compactMap {
            sessionStore.discoveredCharacteristics[$0]
        }.filter { $0.properties.contains(.read) }

        for characteristic in characteristics {
            await eventEmitter.sendDiagnostic(.debug(.init(
                title: BikeSDKText.readTitle,
                detail: "Battery health snapshot \(characteristic.uuid.uuidString)"
            )))
            await peripheralOperations.readValue(characteristic: characteristic, peripheral: peripheral)
        }
    }

    @discardableResult
    private func readAvailableTelemetrySnapshot(
        peripheral: CBPeripheral,
        logsEveryRead: Bool
    ) async -> Bool {
        let characteristics = BikeSDKConstants.telemetrySnapshotUUIDs.compactMap {
            sessionStore.discoveredCharacteristics[$0]
        }.filter { $0.properties.contains(.read) }
        guard !characteristics.isEmpty else { return false }
        for characteristic in characteristics {
            if logsEveryRead || characteristic.uuid == BikeSDKConstants.batterySOCCharacteristicUUID {
                await eventEmitter.sendDiagnostic(.debug(.init(
                    title: BikeSDKText.readTitle,
                    detail: "Telemetry snapshot \(characteristic.uuid.uuidString)"
                )))
            }
            await peripheralOperations.readValue(characteristic: characteristic, peripheral: peripheral)
        }
        return true
    }

    func subscriptionDidTimeOut(characteristicUUID: CBUUID) async {
        await subscriptionCoordinator.subscriptionDidTimeOut(characteristicUUID: characteristicUUID)
    }

    private func requirePeripheralForRead() async throws -> CBPeripheral {
        guard let peripheral = sessionStore.peripheral else {
            try await failRead(BikeSDKText.noActivePeripheral)
        }
        guard sessionStore.authenticationState == .authenticated else {
            try await failRead(BikeSDKText.authenticationRequired)
        }
        return peripheral
    }

    private func failRead(_ message: String) async throws -> Never {
        await eventEmitter.send(.error(.operationFailed(message)))
        throw BikeSDKError.operationFailed(message)
    }
}
