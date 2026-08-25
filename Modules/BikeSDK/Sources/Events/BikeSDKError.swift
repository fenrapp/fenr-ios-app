import Foundation

public enum BikeSDKError: Error, Equatable, LocalizedError, Sendable {
    case notStarted
    case emptyVIN
    case bluetoothUnavailable
    case operationFailed(String)
    case decodeFailed(characteristic: UUID, message: String)

    public var message: String {
        switch self {
        case .notStarted:
            "Bluetooth client has not been started"
        case .emptyVIN:
            "VIN is empty"
        case .bluetoothUnavailable:
            "Bluetooth is unavailable"
        case .operationFailed(let message):
            message
        case .decodeFailed(let characteristic, let message):
            "Decode failed \(characteristic.uuidString): \(message)"
        }
    }

    public var errorDescription: String? { message }
}
