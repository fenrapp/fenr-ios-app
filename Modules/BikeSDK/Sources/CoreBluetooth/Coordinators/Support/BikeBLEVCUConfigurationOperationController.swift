import CoreBluetooth
import Foundation

@MainActor
final class BikeBLEVCUConfigurationOperationController {
    private var activeOperation: BikeBLEVCUConfigurationOperation?
    private var expectedResponse: BikeBLEVCUConfigurationExpectedResponse?
    private var bufferedResponse: Result<Data, BikeSDKError>?
    private let timeoutScheduler: any BikeBLETimeoutScheduling
    private var isDesynchronized = false

    init(timeoutScheduler: any BikeBLETimeoutScheduling) {
        self.timeoutScheduler = timeoutScheduler
    }

    func ensureReady() throws {
        guard activeOperation == nil else {
            throw BikeSDKError.operationFailed("VCU configuration operation is already running")
        }
        guard !isDesynchronized else {
            throw BikeSDKError.operationFailed(
                "VCU configuration transport timed out; reconnect before another transaction"
            )
        }
    }

    func expect(_ response: BikeBLEVCUConfigurationExpectedResponse) {
        expectedResponse = response
        bufferedResponse = nil
    }

    func clearExpectation() {
        expectedResponse = nil
        bufferedResponse = nil
    }

    func takeBufferedResponse() throws -> Data? {
        guard let bufferedResponse else { return nil }
        return try bufferedResponse.get()
    }

    func start(
        uuid: CBUUID,
        kind: BikeBLEVCUConfigurationOperationKind,
        operationName: String,
        continuation: CheckedContinuation<Data, Error>
    ) {
        activeOperation = .init(
            uuid: uuid,
            kind: kind,
            operationName: operationName,
            continuation: continuation
        )
        timeoutScheduler.schedule { [weak self] in
            self?.timeOutOperation(uuid: uuid, kind: kind)
        }
    }

    func completeWrite(uuid: CBUUID, error: Error?) {
        guard let operation = activeOperation,
              operation.uuid == uuid,
              operation.kind == .write else { return }
        finish(operation: operation, error: error, data: Data())
    }

    func completeRead(uuid: CBUUID, data: Data?, error: Error?) -> Bool {
        if captureExpectedResponse(uuid: uuid, data: data, error: error) { return true }
        guard let operation = activeOperation,
              operation.uuid == uuid,
              operation.kind == .read else { return false }
        finish(operation: operation, error: error, data: data ?? Data())
        return true
    }

    func reset() {
        timeoutScheduler.cancel()
        if let operation = activeOperation {
            activeOperation = nil
            operation.continuation.resume(throwing: CancellationError())
        }
        clearExpectation()
        isDesynchronized = false
    }

    private func captureExpectedResponse(uuid: CBUUID, data: Data?, error: Error?) -> Bool {
        guard uuid == BikeSDKConstants.vcuBikeConfigurationUUID,
              let expectedResponse else { return false }
        let result: Result<Data, BikeSDKError>
        if let error {
            result = .failure(.operationFailed("4005 response failed: \(error.localizedDescription)"))
        } else if let data, expectedResponse.matches(data) {
            result = .success(data)
        } else {
            return false
        }
        return capture(result, uuid: uuid)
    }

    private func capture(_ result: Result<Data, BikeSDKError>, uuid: CBUUID) -> Bool {
        if let operation = activeOperation,
           operation.uuid == uuid,
           operation.kind == .configurationResponse {
            complete(operation, with: result)
            return true
        }
        if let operation = activeOperation, operation.uuid == uuid, operation.kind == .write {
            bufferedResponse = result
            BikePowerModeDebugLog.log(
                "4005 response arrived before write callback; buffering until GATT acknowledgement"
            )
            return true
        }
        guard activeOperation != nil else {
            bufferedResponse = result
            BikePowerModeDebugLog.log("4005 response arrived before response wait; buffering")
            return true
        }
        return false
    }

    private func complete(
        _ operation: BikeBLEVCUConfigurationOperation,
        with result: Result<Data, BikeSDKError>
    ) {
        switch result {
        case .success(let data): finish(operation: operation, error: nil, data: data)
        case .failure(let error): finish(operation: operation, error: error, data: Data())
        }
    }

    private func finish(
        operation: BikeBLEVCUConfigurationOperation,
        error: Error?,
        data: Data
    ) {
        timeoutScheduler.cancel()
        activeOperation = nil
        if let error {
            operation.continuation.resume(throwing: BikeSDKError.operationFailed(
                "\(operation.operationName) failed: \(error.localizedDescription)"
            ))
        } else {
            operation.continuation.resume(returning: data)
        }
    }

    private func timeOutOperation(
        uuid: CBUUID,
        kind: BikeBLEVCUConfigurationOperationKind
    ) {
        guard let operation = activeOperation,
              operation.uuid == uuid,
              operation.kind == kind else { return }
        activeOperation = nil
        isDesynchronized = true
        operation.continuation.resume(throwing: BikeSDKError.operationFailed(
            "VCU configuration \(operation.operationName) timed out: \(uuid.uuidString)"
        ))
    }
}
