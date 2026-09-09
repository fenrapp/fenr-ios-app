import Foundation

public struct BikePowerModeEditingUseCases: Sendable {
    private let repository: any BikeControlRepository
    private let presets: any BikePowerModePresetRepository
    public let calibration: BikePowerCurveCalibration

    public init(
        repository: any BikeControlRepository,
        presets: any BikePowerModePresetRepository,
        calibration: BikePowerCurveCalibration
    ) {
        self.repository = repository
        self.presets = presets
        self.calibration = calibration
    }

    public func read(mapIndex: Int) async throws -> BikeAdvancedPowerModeConfiguration {
        try await repository.readAdvancedPowerMode(mapIndex: mapIndex)
    }

    public func apply(
        expected: BikeAdvancedPowerModeConfiguration, desired: BikeAdvancedPowerModeConfiguration,
        maximumHorsepower: Int
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        if expected.power != desired.power,
           !calibration.isRideable(desired.power, maximumHorsepower: maximumHorsepower) {
            throw BikePowerCurveError.invalidValues
        }
        return try await repository.applyAdvancedPowerMode(expected: expected, desired: desired)
    }

    public func applyBasic(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        try await repository.applyBasicPowerMode(
            mapIndex: mapIndex, horsepower: horsepower, regeneration: regeneration
        )
    }

    public func loadPresets(vin: String) async throws -> [BikePowerModePreset] {
        try await presets.load(vin: vin)
    }

    public func savePresets(_ values: [BikePowerModePreset], vin: String) async throws {
        try await presets.save(values, vin: vin)
    }
}
