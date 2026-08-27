import Foundation

public struct BikeBMSSignalsTelemetry: Equatable, Sendable {
    public let voltageCandidateRaw: Int
    public let temperatureRaw: Int
    public let temperatureCelsius: Double
    public let humidityRaw: Int
    public let humidityPercent: Double

    public init(
        voltageCandidateRaw: Int,
        temperatureRaw: Int,
        temperatureCelsius: Double,
        humidityRaw: Int,
        humidityPercent: Double
    ) {
        self.voltageCandidateRaw = voltageCandidateRaw
        self.temperatureRaw = temperatureRaw
        self.temperatureCelsius = temperatureCelsius
        self.humidityRaw = humidityRaw
        self.humidityPercent = humidityPercent
    }
}

public struct BikeBatteryTelemetry: Equatable, Sendable {
    public var stateOfCharge: BatteryLevel
    public var stateOfHealth: HealthLevel
    public var dcBusRaw: Int?
    public var dcBusVolts: Double?
    public var currentRaw: Int?
    public var currentCandidateAmperes: Double?
    public var positiveBMS: BikeBMSSignalsTelemetry?
    public var negativeBMS: BikeBMSSignalsTelemetry?
    public var stateUpdatedAt: Date?
    public var signalsUpdatedAt: Date?

    public init(
        stateOfCharge: BatteryLevel = .unknown,
        stateOfHealth: HealthLevel = .unknown,
        dcBusRaw: Int? = nil,
        dcBusVolts: Double? = nil,
        currentRaw: Int? = nil,
        currentCandidateAmperes: Double? = nil,
        positiveBMS: BikeBMSSignalsTelemetry? = nil,
        negativeBMS: BikeBMSSignalsTelemetry? = nil,
        stateUpdatedAt: Date? = nil,
        signalsUpdatedAt: Date? = nil
    ) {
        self.stateOfCharge = stateOfCharge
        self.stateOfHealth = stateOfHealth
        self.dcBusRaw = dcBusRaw
        self.dcBusVolts = dcBusVolts
        self.currentRaw = currentRaw
        self.currentCandidateAmperes = currentCandidateAmperes
        self.positiveBMS = positiveBMS
        self.negativeBMS = negativeBMS
        self.stateUpdatedAt = stateUpdatedAt
        self.signalsUpdatedAt = signalsUpdatedAt
    }
}
