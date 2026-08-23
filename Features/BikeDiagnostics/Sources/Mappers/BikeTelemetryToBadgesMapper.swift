import BikeDomain

public struct BikeTelemetryToBadgesMapper: Sendable {
    private let runStateMapper: BikeRunStateToBadgeMapper

    public init(runStateMapper: BikeRunStateToBadgeMapper) {
        self.runStateMapper = runStateMapper
    }

    public func map(_ telemetry: BikeTelemetry) -> [String] {
        var badges = [runStateMapper.map(telemetry.runState)]
        if telemetry.statusFlags.isChargerConnected { badges.append("Charger") }
        if telemetry.statusFlags.isFaultActive { badges.append("Fault") }
        return badges
    }
}
