import Foundation

public struct BikePowerModePreset: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public let calibrationProfileID: String
    public let maximumHorsepower: Int
    public let configuration: BikeAdvancedPowerModeConfiguration

    public init(
        id: UUID, name: String, maximumHorsepower: Int, configuration: BikeAdvancedPowerModeConfiguration,
        calibrationProfileID: String = BikePowerCurveCalibration.profileID
    ) {
        self.calibrationProfileID = calibrationProfileID
        self.id = id
        self.name = name
        self.maximumHorsepower = maximumHorsepower
        self.configuration = configuration
    }
}
