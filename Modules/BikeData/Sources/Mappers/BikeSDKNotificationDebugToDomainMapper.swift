import BikeDomain
import BikeSDK

public struct BikeSDKNotificationDebugToDomainMapper: Sendable {
    public init() {}

    public func map(_ notification: BikeSDKNotificationDebug) -> BikeDebugEvent {
        BikeDebugEvent(
            id: notification.characteristic,
            date: notification.date,
            title: "Notification",
            detail: "\(notification.characteristic.uuidString) \(notification.byteCount)b \(notification.hex)"
        )
    }
}
