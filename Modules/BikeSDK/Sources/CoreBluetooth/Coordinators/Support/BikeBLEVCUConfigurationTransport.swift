import CoreBluetooth
import Foundation

@MainActor
final class BikeBLEVCUConfigurationTransport {
    let sessionStore: BLESessionStore
    private let eventEmitter: BikeBLEEventEmitter
    private let peripheralOperations: BikeBLEPeripheralOperations
    let configurationReadinessWaiter: BikeBLEConfigurationReadinessWaiter
    private let transactionGate = BikeBLEVCUConfigurationTransactionGate()
    var activeOperation: BikeBLEVCUConfigurationOperation?
    var expectedConfigurationResponse: BikeBLEVCUConfigurationExpectedResponse?
    var bufferedConfigurationResponse: Result<Data, BikeSDKError>?
    private var timeoutTask: Task<Void, Never>?
    var isDesynchronized = false

    init(
        sessionStore: BLESessionStore,
        eventEmitter: BikeBLEEventEmitter,
        peripheralOperations: BikeBLEPeripheralOperations,
        configurationReadinessWaiter: BikeBLEConfigurationReadinessWaiter
    ) {
        self.sessionStore = sessionStore
        self.eventEmitter = eventEmitter
        self.peripheralOperations = peripheralOperations
        self.configurationReadinessWaiter = configurationReadinessWaiter
    }

    deinit { timeoutTask?.cancel() }
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
        try ensureReady()
        await peripheralOperations.prepareReadValue(characteristic: characteristic)
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
        try ensureReady()
        await peripheralOperations.prepareWriteValue(
            payload,
            characteristic: characteristic,
            type: .withResponse
        )
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
        guard let operation = activeOperation,
              operation.uuid == characteristic.uuid,
              operation.kind == .write
        else {
            return
        }
        finish(operation: operation, error: error, data: Data())
    }

    func completeReadIfNeeded(characteristic: CBCharacteristic, error: Error?) -> Bool {
        if captureConfigurationResponseIfNeeded(characteristic: characteristic, error: error) {
            return true
        }
        guard let operation = activeOperation,
              operation.uuid == characteristic.uuid,
              operation.kind == .read
        else {
            return false
        }
        finish(
            operation: operation,
            error: error,
            data: characteristic.value ?? Data()
        )
        return true
    }

    func reset() {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let operation = activeOperation {
            activeOperation = nil
            operation.continuation.resume(throwing: CancellationError())
        }
        expectedConfigurationResponse = nil
        bufferedConfigurationResponse = nil
        isDesynchronized = false
    }
}
extension BikeBLEVCUConfigurationTransport {
    func awaitConfigurationResponse(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        operationName: String,
        shouldRead: Bool
    ) async throws -> Data {
        try ensureReady()
        if shouldRead {
            await peripheralOperations.prepareReadValue(characteristic: characteristic)
        }
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

    private func captureConfigurationResponseIfNeeded(
        characteristic: CBCharacteristic,
        error: Error?
    ) -> Bool {
        guard characteristic.uuid == BikeSDKConstants.vcuBikeConfigurationUUID,
              let expectedConfigurationResponse
        else {
            return false
        }
        if let error {
            let sdkError = BikeSDKError.operationFailed(
                "4005 response failed: \(error.localizedDescription)"
            )
            return captureConfigurationResult(.failure(sdkError), characteristic: characteristic)
        }
        guard let data = characteristic.value,
              expectedConfigurationResponse.matches(data)
        else {
            return false
        }
        return captureConfigurationResult(.success(data), characteristic: characteristic)
    }

    private func captureConfigurationResult(
        _ result: Result<Data, BikeSDKError>,
        characteristic: CBCharacteristic
    ) -> Bool {
        if let operation = activeOperation,
           operation.uuid == characteristic.uuid,
           operation.kind == .configurationResponse {
            switch result {
            case .success(let data):
                finish(operation: operation, error: nil, data: data)
            case .failure(let error):
                finish(operation: operation, error: error, data: Data())
            }
            return true
        }
        if let operation = activeOperation,
           operation.uuid == characteristic.uuid,
           operation.kind == .write {
            bufferedConfigurationResponse = result
            BikePowerModeDebugLog.log(
                "4005 response arrived before write callback; accepting response as acknowledgement"
            )
            switch result {
            case .success:
                finish(operation: operation, error: nil, data: Data())
            case .failure(let error):
                finish(operation: operation, error: error, data: Data())
            }
            return true
        }
        guard activeOperation != nil else {
            bufferedConfigurationResponse = result
            BikePowerModeDebugLog.log("4005 response arrived before response wait; buffering")
            return true
        }
        return false
    }

    func emitConfigurationDebug(prefix: String, data: Data) async {
        guard BikePowerModeDebugLog.isEnabled else { return }
        BikePowerModeDebugLog.log("4005 \(prefix) \(data.count)b \(data.bikeSDKHexString)")
        await eventEmitter.send(.debug(.init(
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
        activeOperation = BikeBLEVCUConfigurationOperation(
            uuid: uuid,
            kind: kind,
            operationName: operationName,
            continuation: continuation
        )
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard let self,
                  let operation = self.activeOperation,
                  operation.uuid == uuid,
                  operation.kind == kind
            else {
                return
            }
            self.timeoutTask = nil
            self.activeOperation = nil
            self.isDesynchronized = kind != .configurationResponse
            operation.continuation.resume(throwing: BikeSDKError.operationFailed(
                "VCU configuration \(operation.operationName) timed out: \(uuid.uuidString)"
            ))
        }
    }

    private func finish(
        operation: BikeBLEVCUConfigurationOperation,
        error: Error?,
        data: Data
    ) {
        timeoutTask?.cancel()
        timeoutTask = nil
        activeOperation = nil
        if let error {
            operation.continuation.resume(throwing: BikeSDKError.operationFailed(
                "\(operation.operationName) failed: \(error.localizedDescription)"
            ))
        } else {
            operation.continuation.resume(returning: data)
        }
    }

    func withTransaction<Value: Sendable>(
        _ operation: @MainActor () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        await transactionGate.acquire()
        do {
            try Task.checkCancellation()
            let value = try await operation()
            await transactionGate.release()
            return value
        } catch {
            await transactionGate.release()
            throw error
        }
    }
}
