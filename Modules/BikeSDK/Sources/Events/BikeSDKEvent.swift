import Foundation

public enum BikeSDKEvent: Equatable, Sendable {
    case connection(BikeSDKConnectionStatus)
    case discoveredBike(BikeSDKDiscoveredBike)
    case telemetry(BikeSDKTelemetryPayload)
    case imu(BikeSDKIMUSample)
    case batteryDatasetCapture(BikeSDKBatteryDatasetCapture)
    case rssi(Int)
    case peripheral(name: String?, identifier: UUID)
    case notification(BikeSDKNotificationDebug)
    case debug(BikeSDKDebugEvent)
    case error(BikeSDKError)
}
