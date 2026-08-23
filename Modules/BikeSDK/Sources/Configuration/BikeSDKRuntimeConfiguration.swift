import Foundation

public struct BikeSDKRuntimeConfiguration: Sendable {
    public let eventBufferLimit: Int
    public let notificationDebugMinimumInterval: TimeInterval
    public let securityOperationTimeout: Duration
    public let subscriptionOperationTimeout: Duration
    public let reconnectPolicy: BikeBLEReconnectPolicy

    public init(
        eventBufferLimit: Int = 256,
        notificationDebugMinimumInterval: TimeInterval = 1,
        securityOperationTimeout: Duration = .seconds(10),
        subscriptionOperationTimeout: Duration = .seconds(8),
        reconnectPolicy: BikeBLEReconnectPolicy = .standard
    ) {
        self.eventBufferLimit = eventBufferLimit
        self.notificationDebugMinimumInterval = notificationDebugMinimumInterval
        self.securityOperationTimeout = securityOperationTimeout
        self.subscriptionOperationTimeout = subscriptionOperationTimeout
        self.reconnectPolicy = reconnectPolicy
    }
}
