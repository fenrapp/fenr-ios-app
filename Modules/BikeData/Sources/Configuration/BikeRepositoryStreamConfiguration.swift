public struct BikeRepositoryStreamConfiguration: Sendable {
    public let telemetryBufferLimit: Int
    public let connectionBufferLimit: Int
    public let debugBufferLimit: Int
    public let batteryHealthBufferLimit: Int
    public let batteryCaptureBufferLimit: Int

    public init(
        telemetryBufferLimit: Int = 1,
        connectionBufferLimit: Int = 1,
        debugBufferLimit: Int = 128,
        batteryHealthBufferLimit: Int = 1,
        batteryCaptureBufferLimit: Int = 16
    ) {
        self.telemetryBufferLimit = telemetryBufferLimit
        self.connectionBufferLimit = connectionBufferLimit
        self.debugBufferLimit = debugBufferLimit
        self.batteryHealthBufferLimit = batteryHealthBufferLimit
        self.batteryCaptureBufferLimit = batteryCaptureBufferLimit
    }
}
