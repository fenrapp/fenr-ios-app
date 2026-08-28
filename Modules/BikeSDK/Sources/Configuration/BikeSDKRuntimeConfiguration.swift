import Foundation
import RuntimeConfiguration

public struct BikeSDKRuntimeConfiguration: Sendable {
    public let eventBufferLimit: Int
    public let notificationDebugMinimumInterval: TimeInterval
    public let connectionOperationTimeout: Duration
    public let connectionStabilityPeriod: Duration
    public let securityOperationTimeout: Duration
    public let subscriptionOperationTimeout: Duration
    public let reconnectPolicy: BikeBLEReconnectPolicy

    public init(
        eventBufferLimit: Int = 256,
        notificationDebugMinimumInterval: TimeInterval =
            FENRRuntimeConstants.BikeSDK.notificationDebugMinimumInterval,
        connectionOperationTimeout: Duration = FENRRuntimeConstants.BikeSDK.connectionOperationTimeout,
        connectionStabilityPeriod: Duration = FENRRuntimeConstants.Telemetry.connectionStabilityPeriod,
        securityOperationTimeout: Duration = FENRRuntimeConstants.BikeSDK.securityOperationTimeout,
        subscriptionOperationTimeout: Duration = FENRRuntimeConstants.BikeSDK.subscriptionOperationTimeout,
        reconnectPolicy: BikeBLEReconnectPolicy = .standard
    ) {
        self.eventBufferLimit = eventBufferLimit
        self.notificationDebugMinimumInterval = notificationDebugMinimumInterval
        self.connectionOperationTimeout = connectionOperationTimeout
        self.connectionStabilityPeriod = connectionStabilityPeriod
        self.securityOperationTimeout = securityOperationTimeout
        self.subscriptionOperationTimeout = subscriptionOperationTimeout
        self.reconnectPolicy = reconnectPolicy
    }
}
