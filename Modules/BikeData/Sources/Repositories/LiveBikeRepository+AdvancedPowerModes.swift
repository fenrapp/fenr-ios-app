import BikeDomain

extension LiveBikeRepository {
    public func readAdvancedPowerMode(mapIndex: Int) async throws -> BikeAdvancedPowerModeConfiguration {
        try await curveConfirmation.perform(mapIndex: mapIndex) {
            try await self.controlService.readAdvancedPowerMode(mapIndex: mapIndex)
        }
    }
    public func applyAdvancedPowerMode(
        expected: BikeAdvancedPowerModeConfiguration, desired: BikeAdvancedPowerModeConfiguration
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        try await curveConfirmation.perform(mapIndex: expected.mapIndex, advancedEditBaseline: expected) {
            try await self.controlService.applyAdvancedPowerMode(expected: expected, desired: desired)
        }
    }
    public func applyBasicPowerMode(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        try await curveConfirmation.perform(mapIndex: mapIndex) {
            try await self.controlService.applyBasicPowerMode(
                mapIndex: mapIndex, horsepower: horsepower, regeneration: regeneration
            )
        }
    }
}
