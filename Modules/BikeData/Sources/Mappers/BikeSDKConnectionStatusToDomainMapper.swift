import BikeDomain
import BikeSDK

public struct BikeSDKConnectionStatusToDomainMapper: Sendable {
    public init() {}

    public func map(_ status: BikeSDKConnectionStatus) -> ConnectionState {
        switch status {
        case .idle:
            .idle
        case .bluetoothUnavailable:
            .bluetoothUnavailable
        case .bluetoothUnauthorized:
            .bluetoothUnauthorized
        case .bluetoothPoweredOff:
            .bluetoothPoweredOff
        case .scanning(let vin):
            .scanning(vin: vin)
        case .connecting(let vin, let peripheralName):
            .connecting(vin: vin, peripheralName: peripheralName)
        case .discovering(let peripheralName):
            .discovering(peripheralName: peripheralName)
        case .authenticating(let peripheralName):
            .authenticating(peripheralName: peripheralName)
        case .authenticated(let peripheralName):
            .authenticated(peripheralName: peripheralName)
        case .subscribed(let peripheralName):
            .subscribed(peripheralName: peripheralName)
        case .receivingTelemetry(let peripheralName):
            .receivingTelemetry(peripheralName: peripheralName)
        case .reconnecting(let vin, let attempt, let maximumAttempts):
            .reconnecting(vin: vin, attempt: attempt, maximumAttempts: maximumAttempts)
        case .disconnected(let reason):
            .disconnected(reason: reason)
        case .failed(let message):
            .failed(message: message)
        }
    }
}
