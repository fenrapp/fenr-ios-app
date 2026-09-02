import BikeDomain
import Foundation

public struct BikeTelemetryToBadgesMapper: Sendable {
    private let runStateMapper: BikeRunStateToBadgeMapper

    public init(runStateMapper: BikeRunStateToBadgeMapper) {
        self.runStateMapper = runStateMapper
    }

    public func map(_ telemetry: BikeTelemetry) -> [BikeDiagnosticsBadgeViewData] {
        var badges = [runStateMapper.map(telemetry.runState)]
        if telemetry.statusFlags.isChargerConnected {
            badges.append(.init(kind: .charger, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateCharger)))
        }
        if telemetry.statusFlags.isFaultActive {
            badges.append(.init(kind: .fault, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateFault)))
        }
        return badges
    }
}
