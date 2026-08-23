import BikeDomain

public struct RideDashboardViewState: Equatable, Sendable {
    public var speed: RideDashboardMeasurement?
    public var speedometerMaximum: RideDashboardMeasurement
    public var batteryPercent: Int?
    public var odometer: RideDashboardMeasurement?
    public var modeIndex: Int?
    public var runState: RideDashboardRunState
    public var connectionDetail: String
    public var hasTelemetry: Bool
    public var isHighBeamOn: Bool
    public var isLeftBlinkerOn: Bool
    public var isRightBlinkerOn: Bool
    public var isBrakeActive: Bool
    public var isFaultActive: Bool

    public init(
        speed: RideDashboardMeasurement? = nil,
        speedometerMaximum: RideDashboardMeasurement = RideDashboardMeasurement(value: 180, unit: "km/h"),
        batteryPercent: Int? = nil,
        odometer: RideDashboardMeasurement? = nil,
        modeIndex: Int? = nil,
        runState: RideDashboardRunState = .offline,
        connectionDetail: String = "Connect your bike from Diagnostics.",
        hasTelemetry: Bool = false,
        isHighBeamOn: Bool = false,
        isLeftBlinkerOn: Bool = false,
        isRightBlinkerOn: Bool = false,
        isBrakeActive: Bool = false,
        isFaultActive: Bool = false
    ) {
        self.speed = speed
        self.speedometerMaximum = speedometerMaximum
        self.batteryPercent = batteryPercent
        self.odometer = odometer
        self.modeIndex = modeIndex
        self.runState = runState
        self.connectionDetail = connectionDetail
        self.hasTelemetry = hasTelemetry
        self.isHighBeamOn = isHighBeamOn
        self.isLeftBlinkerOn = isLeftBlinkerOn
        self.isRightBlinkerOn = isRightBlinkerOn
        self.isBrakeActive = isBrakeActive
        self.isFaultActive = isFaultActive
    }
}

public enum RideDashboardRunState: Equatable, Sendable {
    case offline
    case off
    case neutral
    case ride
    case charging
    case crawlForward
    case crawlReverse

}
