import BikeDomain

extension LiveBikeRepository {
    public func readTractionControlFirmwareCompatibility() async throws -> BikeTractionControlFirmwareCompatibility {
        try await controlService.readTractionControlFirmwareCompatibility()
    }

    public func applyUserTractionControlConfiguration(
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double,
        expected: BikeTractionControlSnapshot?
    ) async throws -> BikeTractionControlSnapshot {
        try await controlService.applyUserTractionControlConfiguration(
            mapIndex: mapIndex, powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent, expected: expected
        )
    }

}
