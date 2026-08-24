import Foundation
import RuntimeConfiguration

public struct BikeSDKRuntimeConfiguration: Sendable {
    public let eventBufferLimit: Int
    public let notificationDebugMinimumInterval: TimeInterval
    public let securityOperationTimeout: Duration
    public let subscriptionOperationTimeout: Duration
    public let reconnectPolicy: BikeBLEReconnectPolicy

    public init(
        eventBufferLimit: Int = 256,
        notificationDebugMinimumInterval: TimeInterval =
            FENRRuntimeConstants.BikeSDK.notificationDebugMinimumInterval,
        securityOperationTimeout: Duration = FENRRuntimeConstants.BikeSDK.securityOperationTimeout,
        subscriptionOperationTimeout: Duration = FENRRuntimeConstants.BikeSDK.subscriptionOperationTimeout,
        reconnectPolicy: BikeBLEReconnectPolicy = .standard
    ) {
        self.eventBufferLimit = eventBufferLimit
        self.notificationDebugMinimumInterval = notificationDebugMinimumInterval
        self.securityOperationTimeout = securityOperationTimeout
        self.subscriptionOperationTimeout = subscriptionOperationTimeout
        self.reconnectPolicy = reconnectPolicy
    }
}
