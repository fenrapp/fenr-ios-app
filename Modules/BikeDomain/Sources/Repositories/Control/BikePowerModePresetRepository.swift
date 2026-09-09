public protocol BikePowerModePresetRepository: Sendable {
    func load(vin: String) async throws -> [BikePowerModePreset]
    func save(_ presets: [BikePowerModePreset], vin: String) async throws
}
