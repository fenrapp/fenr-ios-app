import BikeDomain
import BikeSDK
import Foundation

public struct BikeSDKEventToDomainMapper: Sendable {
    private let connectionMapper: BikeSDKConnectionStatusToDomainMapper
    private let connectionDebugMapper: BikeSDKConnectionStatusDebugMapper
    private let notificationDebugMapper: BikeSDKNotificationDebugToDomainMapper

    public init(
        connectionMapper: BikeSDKConnectionStatusToDomainMapper,
        connectionDebugMapper: BikeSDKConnectionStatusDebugMapper,
        notificationDebugMapper: BikeSDKNotificationDebugToDomainMapper
    ) {
        self.connectionMapper = connectionMapper
        self.connectionDebugMapper = connectionDebugMapper
        self.notificationDebugMapper = notificationDebugMapper
    }

    public func connectionState(from status: BikeSDKConnectionStatus) -> ConnectionState {
        connectionMapper.map(status)
    }

    public func connectionDebug(from status: BikeSDKConnectionStatus) -> BikeDebugEvent {
        BikeDebugEvent(title: "Connection", detail: connectionDebugMapper.map(status))
    }

    public func rssiDebug(_ rssi: Int) -> BikeDebugEvent {
        BikeDebugEvent(title: "RSSI", detail: "\(rssi) dBm")
    }

    public func peripheralDebug(name _: String?, identifier _: UUID) -> BikeDebugEvent {
        BikeDebugEvent(title: "Peripheral", detail: "Peripheral discovered")
    }

    public func notificationDebug(_ notification: BikeSDKNotificationDebug) -> BikeDebugEvent {
        let event = notificationDebugMapper.map(notification)
        return BikeDebugEvent(
            id: event.id,
            date: event.date,
            title: event.title,
            detail: event.detail.replacingOccurrences(
                of: "\(notification.characteristic.uuidString) ",
                with: ""
            )
        )
    }

    public func sdkDebug(_ event: BikeSDKDebugEvent) -> BikeDebugEvent {
        BikeDebugEvent(date: event.date, title: event.title, detail: event.detail)
    }

    public func errorDebug(_ error: BikeSDKError) -> BikeDebugEvent {
        BikeDebugEvent(title: "Error", detail: error.message)
    }
}
