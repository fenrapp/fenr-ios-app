import CoreBluetooth
import Foundation

@MainActor
final class BikeBLEVCUConfigurationTransport {
    private var generation = 0
    private var transactionGeneration: Int?
    let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let peripheralOperations: BikeBLEPeripheralOperations
    let configurationReadinessWaiter: BikeBLEConfigurationReadinessWaiter
    private let transactionGate: BikeBLEVCUConfigurationTransactionGate
    let operationController: BikeBLEVCUConfigurationOperationController

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        peripheralOperations: BikeBLEPeripheralOperations,
        configurationReadinessWaiter: BikeBLEConfigurationReadinessWaiter,
        transactionGate: BikeBLEVCUConfigurationTransactionGate,
        operationController: BikeBLEVCUConfigurationOperationController
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.peripheralOperations = peripheralOperations
        self.configurationReadinessWaiter = configurationReadinessWaiter
        self.transactionGate = transactionGate
        self.operationController = operationController
    }

    func authenticatedPeripheral() throws -> CBPeripheral {
        guard let peripheral = sessionStore.peripheral else {
            BikePowerModeDebugLog.log("transport rejected operation: no active peripheral")
            throw BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)
        }
        guard sessionStore.authenticationState == .authenticated else {
            BikePowerModeDebugLog.log(
                "transport rejected operation: authentication=\(sessionStore.authenticationState)"
            )
            throw BikeSDKError.operationFailed(BikeSDKText.authenticationRequired)
        }
        return peripheral
    }

    func configurationReadPeripheral(
        allowLiveTelemetrySession: Bool
    ) throws -> CBPeripheral {
        guard let peripheral = sessionStore.peripheral else {
            BikePowerModeDebugLog.log("transport rejected operation: no active peripheral")
            throw BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)
        }
        guard sessionStore.authenticationState == .authenticated else {
            guard allowLiveTelemetrySession,
                  sessionStore.hasReportedCompleteTelemetry
            else {
                BikePowerModeDebugLog.log(
                    "transport rejected operation: authentication=\(sessionStore.authenticationState)"
                )
                throw BikeSDKError.operationFailed(BikeSDKText.authenticationRequired)
            }
            BikePowerModeDebugLog.log(
                "4005 read allowed without a new handshake; live telemetry is active"
            )
            return peripheral
        }
        return peripheral
    }
    func configurationCharacteristic() throws -> CBCharacteristic {
        let characteristicUUID = BikeSDKConstants.vcuBikeConfigurationUUID
        guard let characteristic = sessionStore.discoveredCharacteristics[characteristicUUID] else {
            throw BikeSDKError.operationFailed("VCU configuration characteristic 4005 is unavailable")
        }
        guard characteristic.properties.contains(.write) else {
            throw BikeSDKError.operationFailed(
                "VCU configuration characteristic 4005 does not support write with response"
            )
        }
        return characteristic
    }

    func versionsCharacteristic() throws -> CBCharacteristic {
        guard let characteristic = sessionStore.discoveredCharacteristics[BikeSDKConstants.vcuVersionsUUID],
              characteristic.properties.contains(.read)
        else {
            throw BikeSDKError.operationFailed("VCU versions characteristic 4001 is unavailable")
        }
        return characteristic
    }

    func read(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        operationName: String
    ) async throws -> Data {
        let token = generation
        try ensureReady()
        await peripheralOperations.prepareReadValue(characteristic: characteristic)
        try checkGeneration(token)
        return try await withCheckedThrowingContinuation { continuation in
            startOperation(
                uuid: characteristic.uuid,
                kind: .read,
                operationName: operationName,
                continuation: continuation
            )
            peripheral.readValue(for: characteristic)
        }
    }

    func write(
        _ payload: Data,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async throws {
        let token = generation
        try ensureReady()
        guard payload.count <= peripheral.maximumWriteValueLength(for: .withResponse) else {
            throw BikeSDKError.operationFailed("VCU configuration exceeds the supported write length")
        }
        await peripheralOperations.prepareWriteValue(
            payload,
            characteristic: characteristic,
            type: .withResponse
        )
        try checkGeneration(token)
        _ = try await withCheckedThrowingContinuation { continuation in
            startOperation(
                uuid: characteristic.uuid,
                kind: .write,
                operationName: "4005 write",
                continuation: continuation
            )
            peripheral.writeValue(payload, for: characteristic, type: .withResponse)
        } as Data
        await emitConfigurationDebug(prefix: "Write acknowledged", data: Data())
    }

    func completeWriteIfNeeded(characteristic: CBCharacteristic, error: Error?) {
        operationController.completeWrite(uuid: characteristic.uuid, error: error)
    }

    func completeReadIfNeeded(characteristic: CBCharacteristic, error: Error?) -> Bool {
        operationController.completeRead(
            uuid: characteristic.uuid,
            data: characteristic.value,
            error: error
        )
    }

    func checkTransactionGeneration() throws {
        try Task.checkCancellation()
        if let transactionGeneration, transactionGeneration != generation { throw CancellationError() }
    }

    private func checkGeneration(_ token: Int) throws {
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
        try ensureReady()
    }

    func reset() {
        generation += 1
        operationController.reset()
    }
}
extension BikeBLEVCUConfigurationTransport {
    func awaitConfigurationResponse(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        operationName: String,
        shouldRead: Bool
    ) async throws -> Data {
        let token = generation
        try ensureReady()
        if shouldRead {
            await peripheralOperations.prepareReadValue(characteristic: characteristic)
        }
        try checkGeneration(token)
        return try await withCheckedThrowingContinuation { continuation in
            startOperation(
                uuid: characteristic.uuid,
                kind: .configurationResponse,
                operationName: operationName,
                continuation: continuation
            )
            if shouldRead {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func emitConfigurationDebug(prefix: String, data: Data) async {
        guard eventEmitter.isRecordingDiagnostics || BikePowerModeDebugLog.isEnabled else { return }
        BikePowerModeDebugLog.log("4005 \(prefix) \(data.count)b \(data.bikeSDKHexString)")
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: "VCU 4005",
            detail: "\(prefix) \(data.count)b \(data.bikeSDKHexString)"
        )))
    }

    private func startOperation(
        uuid: CBUUID,
        kind: BikeBLEVCUConfigurationOperationKind,
        operationName: String,
        continuation: CheckedContinuation<Data, Error>
    ) {
        operationController.start(
            uuid: uuid,
            kind: kind,
            operationName: operationName,
            continuation: continuation
        )
    }

    func withTransaction<Value: Sendable>(
        _ operation: @MainActor () async throws -> Value
    ) async throws -> Value {
        let token = generation
        try Task.checkCancellation()
        try await transactionGate.acquireCancellable()
        do {
            try Task.checkCancellation()
            guard token == generation else { throw CancellationError() }
            transactionGeneration = token
            let value = try await operation()
            try Task.checkCancellation()
            guard token == generation else { throw CancellationError() }
            transactionGeneration = nil
            await transactionGate.release()
            return value
        } catch {
            transactionGeneration = nil
            await transactionGate.release()
            throw error
        }
    }
}
