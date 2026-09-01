import CoreBluetooth
import Foundation

struct BikeBLEVCUConfigurationOperation {
    let uuid: CBUUID
    let kind: BikeBLEVCUConfigurationOperationKind
    let operationName: String
    let continuation: CheckedContinuation<Data, Error>
}

enum BikeBLEVCUConfigurationOperationKind { case read, write, configurationResponse }

struct BikeBLEVCUConfigurationExpectedResponse {
    let type: UInt8
    let mapIndex: UInt8?
    let allowedOperations: Set<UInt8>

    init(request: Data) throws {
        guard (2 ... 3).contains(request.count), request[0] == 0 else {
            throw BikeSDKError.operationFailed("Invalid 4005 read request")
        }
        type = request[1]
        mapIndex = request.count == 3 ? request[2] : nil
        allowedOperations = [0, 2]
    }

    init(writeRequest: Data) throws {
        guard writeRequest.count >= 2, writeRequest[0] == 1 else {
            throw BikeSDKError.operationFailed("Invalid 4005 write request")
        }
        type = writeRequest[1]
        mapIndex = nil
        allowedOperations = [1]
    }

    func matches(_ response: Data) -> Bool {
        guard response.count >= 2,
              allowedOperations.contains(response[0]),
              response[1] == type
        else {
            return false
        }
        guard let mapIndex else { return true }
        return response.count < 4 || response[3] == mapIndex
    }
}

actor BikeBLEVCUConfigurationTransactionGate {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var waiterTokens: [UInt64?] = []
    private var cancelledWaiterTokens: Set<UInt64> = []
    private var nextWaiterToken: UInt64 = 0

    var pendingWaiterCount: Int { waiters.count }

    func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
            waiterTokens.append(nil)
        }
    }

    func acquireCancellable() async throws {
        try Task.checkCancellation()
        guard isLocked else {
            isLocked = true
            return
        }

        let token = nextWaiterToken
        nextWaiterToken &+= 1
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
                waiterTokens.append(token)
            }
        } onCancel: {
            Task { await self.cancelWaiter(token) }
        }

        if cancelledWaiterTokens.remove(token) != nil {
            throw CancellationError()
        }

        do {
            try Task.checkCancellation()
        } catch {
            release()
            throw error
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiterTokens.removeFirst()
        waiters.removeFirst().resume()
    }

    private func cancelWaiter(_ token: UInt64) {
        guard let index = waiterTokens.firstIndex(where: { $0 == token }) else { return }
        waiterTokens.remove(at: index)
        let continuation = waiters.remove(at: index)
        cancelledWaiterTokens.insert(token)
        continuation.resume()
    }
}
