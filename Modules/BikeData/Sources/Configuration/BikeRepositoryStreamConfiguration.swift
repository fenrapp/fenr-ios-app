import Foundation

public struct BikeRepositoryStreamConfiguration: Sendable {
    public let telemetryBufferLimit: Int
    public let connectionBufferLimit: Int
    public let debugBufferLimit: Int
    public let imuBufferLimit: Int
    public let imuMinimumInterval: TimeInterval
    public let batteryHealthBufferLimit: Int
    public let batteryCaptureBufferLimit: Int

    public init(
        telemetryBufferLimit: Int = 1,
        connectionBufferLimit: Int = 1,
        debugBufferLimit: Int = 128,
        imuBufferLimit: Int = 1,
        imuMinimumInterval: TimeInterval = 0.1,
        batteryHealthBufferLimit: Int = 1,
        batteryCaptureBufferLimit: Int = 16
    ) {
        self.telemetryBufferLimit = telemetryBufferLimit
        self.connectionBufferLimit = connectionBufferLimit
        self.debugBufferLimit = debugBufferLimit
        self.imuBufferLimit = imuBufferLimit
        self.imuMinimumInterval = imuMinimumInterval
        self.batteryHealthBufferLimit = batteryHealthBufferLimit
        self.batteryCaptureBufferLimit = batteryCaptureBufferLimit
    }
}
