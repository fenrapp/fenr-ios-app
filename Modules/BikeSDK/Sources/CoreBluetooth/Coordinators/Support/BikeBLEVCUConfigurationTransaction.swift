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

    init(request: Data) throws {
        guard (2 ... 3).contains(request.count), request[0] == 0 else {
            throw BikeSDKError.operationFailed("Invalid 4005 read request")
        }
        type = request[1]
        mapIndex = request.count == 3 ? request[2] : nil
    }

    func matches(_ response: Data) -> Bool {
        guard response.count >= 2,
              response[0] == 0 || response[0] == 2,
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

    func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}
