import CoreBluetooth
import Foundation

@MainActor
public struct BikeBLENotificationCoordinator {
    let sessionStore: BLESessionStore
    let eventEmitter: BikeBLEEventEmitter
    private let notificationProcessor: BikeBLENotificationProcessor
    private let subscriptionCoordinator: BikeBLESubscriptionCoordinator
    private let chargePowerCoordinator: BikeBLEChargePowerCoordinator
    private let powerModeCoordinator: BikeBLEPowerModeConfigurationCoordinator
    private let configurationTransport: BikeBLEVCUConfigurationTransport

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationProcessor: BikeBLENotificationProcessor,
        subscriptionCoordinator: BikeBLESubscriptionCoordinator,
        chargePowerCoordinator: BikeBLEChargePowerCoordinator,
        powerModeCoordinator: BikeBLEPowerModeConfigurationCoordinator,
        configurationTransport: BikeBLEVCUConfigurationTransport
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.notificationProcessor = notificationProcessor
        self.subscriptionCoordinator = subscriptionCoordinator
        self.chargePowerCoordinator = chargePowerCoordinator
        self.powerModeCoordinator = powerModeCoordinator
        self.configurationTransport = configurationTransport
    }

    public func discovered(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        sessionStore.setCharacteristic(characteristic)
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.characteristicTitle,
            detail: "\(characteristic.uuid.uuidString) \(characteristic.properties.protocolDescription)"
        )))
        await subscriptionCoordinator.prepareIfNeeded(
            characteristic: characteristic,
            peripheral: peripheral
        )
        if characteristic.uuid == BikeSDKConstants.vcuBikeConfigurationUUID {
            powerModeCoordinator.startAutomaticRefreshIfNeeded()
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
        if let error {
            let message = "Value update failed \(characteristicUUIDString): \(error.localizedDescription)"
            await eventEmitter.send(.error(.operationFailed(message)))
            return
        }
        guard let data = characteristic.value else { return }
        let uuid = characteristic.uuid.foundationUUID
        let date = Date()
        if sessionStore.isBatteryHealthMonitoringActive(),
           let dataset = BikeSDKConstants.batteryDataset(for: characteristic.uuid) {
            await eventEmitter.send(.batteryDatasetCapture(.init(
                dataset: dataset,
                byteCount: data.count,
                hex: data.bikeSDKHexString,
                date: date
            )))
        }
        let didDecodeTelemetry = await notificationProcessor.process(characteristic: uuid, data: data, date: date)
        if didDecodeTelemetry, sessionStore.markTelemetryReceived(
            characteristicUUID: characteristic.uuid,
            requiredCharacteristicUUIDs: BikeSDKConstants.requiredTelemetryNotifyUUIDs
        ) {
            await eventEmitter.send(.connection(.receivingTelemetry(peripheralName: peripheral.name)))
        }
        if didDecodeTelemetry {
            powerModeCoordinator.startAutomaticRefreshIfNeeded()
        }
    }

    public func didReadRSSI(_ rssi: Int, error: Error?) async {
        guard error == nil else { return }
        await eventEmitter.send(.rssi(rssi))
    }

    public func authenticationDidSucceed(peripheral: CBPeripheral) async {
        notificationProcessor.resetDebugSampling()
        await subscriptionCoordinator.authenticationDidSucceed(peripheral: peripheral)
        await readAvailableTelemetrySnapshot(peripheral: peripheral, logsEveryRead: false)
        powerModeCoordinator.startAutomaticRefreshIfNeeded()
    }

    public func startBatteryHealthMonitoring() async throws {
        try await subscriptionCoordinator.startBatteryHealthMonitoring()
    }

    public func stopBatteryHealthMonitoring() async {
        await subscriptionCoordinator.stopBatteryHealthMonitoring()
    }

    public func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        try await chargePowerCoordinator.prepareChargePowerControl(context: context)
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        try await chargePowerCoordinator.setChargePowerLimit(watts: watts)
    }

    public func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        try await chargePowerCoordinator.setChargeTarget(percent: percent)
    }

    public func refreshPowerModeConfigurations() async throws {
        try await powerModeCoordinator.refresh()
    }

    public func didWriteValue(characteristic: CBCharacteristic, error: Error?) async {
        configurationTransport.completeWriteIfNeeded(characteristic: characteristic, error: error)
    }

    public func resetSession() {
        subscriptionCoordinator.reset()
        chargePowerCoordinator.reset()
        powerModeCoordinator.reset()
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
        peripheral.readValue(for: characteristic)
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
                await eventEmitter.send(.debug(.init(
                    title: BikeSDKText.readTitle,
                    detail: "Telemetry snapshot \(characteristic.uuid.uuidString)"
                )))
            }
            peripheral.readValue(for: characteristic)
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
