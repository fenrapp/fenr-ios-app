import CoreBluetooth
import Foundation

@MainActor
final class BikeBLEChargePowerTransport {
    private let sessionStore: BLESessionStore
    private var activeOperation: BikeBLEChargePowerOperation?
    private var timeoutTask: Task<Void, Never>?
    private var isDesynchronized = false

    init(sessionStore: BLESessionStore) {
        self.sessionStore = sessionStore
    }

    deinit {
        timeoutTask?.cancel()
    }

    func ensureReady() throws {
        guard activeOperation == nil else {
            throw BikeSDKError.operationFailed("Charge power control operation is already running")
        }
        guard !isDesynchronized else {
            throw BikeSDKError.operationFailed(
                "Charge power control timed out; reconnect before preparing another write"
            )
        }
    }

    func authenticatedPeripheral() throws -> CBPeripheral {
        guard let peripheral = sessionStore.peripheral else {
            throw BikeSDKError.operationFailed(BikeSDKText.noActivePeripheral)
        }
        guard sessionStore.authenticationState == .authenticated else {
            throw BikeSDKError.operationFailed(BikeSDKText.authenticationRequired)
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
        _ = try await withCheckedThrowingContinuation { continuation in
            startOperation(
                uuid: characteristic.uuid,
                kind: .write,
                operationName: "4005 write",
                continuation: continuation
            )
            peripheral.writeValue(payload, for: characteristic, type: .withResponse)
        } as Data
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
        isDesynchronized = false
    }

    private func startOperation(
        uuid: CBUUID,
        kind: BikeBLEChargePowerOperationKind,
        operationName: String,
        continuation: CheckedContinuation<Data, Error>
    ) {
        activeOperation = BikeBLEChargePowerOperation(
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
            self.isDesynchronized = true
            operation.continuation.resume(throwing: BikeSDKError.operationFailed(
                "Charge power control \(operation.operationName) timed out: \(uuid.uuidString)"
            ))
        }
    }

    private func finish(
        operation: BikeBLEChargePowerOperation,
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
}

private struct BikeBLEChargePowerOperation {
    let uuid: CBUUID
    let kind: BikeBLEChargePowerOperationKind
    let operationName: String
    let continuation: CheckedContinuation<Data, Error>
}

private enum BikeBLEChargePowerOperationKind {
    case read
    case write
}
