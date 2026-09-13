import BikeDomain
import Foundation

extension BikeEmulatorRepository {
    public func readTractionControlFirmwareCompatibility() async throws -> BikeTractionControlFirmwareCompatibility {
        try validateDemoConnection()
        return .init(firmware: "1.12.0", isCompatible: true)
    }

    public func applyUserTractionControlConfiguration(
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double
    ) async throws -> BikeTractionControlSnapshot {
        try validateDemoConnection()
        try Task.checkCancellation()
        guard 0 ... 4 ~= mapIndex,
              [powerTractionPercent, brakingTractionPercent].allSatisfy({
                  $0.isFinite && 0 ... 100 ~= $0 && $0.rounded() == $0
              }) else { throw BikeTractionControlError.rejected }
        guard powerModePreset != .failure else { throw BikeTractionControlError.confirmationUnavailable }
        var current = currentPowerModeConfigurations()[mapIndex] ?? .init(mapIndex: mapIndex)
        current.powerTractionPercent = powerTractionPercent
        current.brakingTractionPercent = brakingTractionPercent
        powerModeOverrides[mapIndex] = current
        persistState()
        await publishCurrentState()
        return .init(
            mapIndex: mapIndex, powerRaw: Int(powerTractionPercent * 10),
            brakingRaw: Int(brakingTractionPercent * 10)
        )
    }
}
