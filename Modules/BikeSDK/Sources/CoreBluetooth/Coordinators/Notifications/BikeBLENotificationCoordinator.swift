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
    private let connectionDidBecomeReady: @MainActor () -> Void
    private let peripheralOperations: BikeBLEPeripheralOperations

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        notificationProcessor: BikeBLENotificationProcessor,
        subscriptionCoordinator: BikeBLESubscriptionCoordinator,
        chargePowerCoordinator: BikeBLEChargePowerCoordinator,
        powerModeCoordinator: BikeBLEPowerModeConfigurationCoordinator,
        configurationTransport: BikeBLEVCUConfigurationTransport,
        connectionDidBecomeReady: @escaping @MainActor () -> Void,
        peripheralOperations: BikeBLEPeripheralOperations
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.notificationProcessor = notificationProcessor
        self.subscriptionCoordinator = subscriptionCoordinator
        self.chargePowerCoordinator = chargePowerCoordinator
        self.powerModeCoordinator = powerModeCoordinator
        self.configurationTransport = configurationTransport
        self.connectionDidBecomeReady = connectionDidBecomeReady
        self.peripheralOperations = peripheralOperations
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
            connectionDidBecomeReady()
            await eventEmitter.send(.connection(.receivingTelemetry(peripheralName: peripheral.name)))
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
    }

    public func startBatteryHealthMonitoring() async throws {
        try await subscriptionCoordinator.startBatteryHealthMonitoring()
        try await readAvailableBatteryHealthSnapshot()
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

    public func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try await powerModeCoordinator.refreshPowerModeConfiguration(mapIndex: mapIndex)
    }

    public func preparePowerModeControl(mapIndex: Int) async throws {
        try await powerModeCoordinator.preparePowerModeControl(mapIndex: mapIndex)
    }

    public func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try await powerModeCoordinator.setPowerModeConfiguration(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        )
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
        try await powerModeCoordinator.prepareTractionControl(mapIndex: mapIndex)
    }

    public func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try await powerModeCoordinator.setTractionControlConfiguration(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
    }

    public func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try await powerModeCoordinator.refreshTractionControlConfiguration(mapIndex: mapIndex)
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
        await peripheralOperations.readValue(characteristic: characteristic, peripheral: peripheral)
    }

    private func readAvailableBatteryHealthSnapshot() async throws {
        let peripheral = try await requirePeripheralForRead()
        let characteristics = BikeSDKConstants.batteryHealthMonitoringUUIDs.compactMap {
            sessionStore.discoveredCharacteristics[$0]
        }.filter { $0.properties.contains(.read) }

        for characteristic in characteristics {
            await eventEmitter.send(.debug(.init(
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
                await eventEmitter.send(.debug(.init(
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
