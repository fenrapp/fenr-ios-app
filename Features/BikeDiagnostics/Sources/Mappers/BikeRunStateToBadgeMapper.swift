import BikeDomain
import Foundation

public struct BikeRunStateToBadgeMapper: Sendable {
    public init() {}

    public func map(_ runState: BikeRunState) -> BikeDiagnosticsBadgeViewData {
        switch runState {
        case .unknown:
            .init(kind: .unknown, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateUnknown))
        case .off:
            .init(kind: .off, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateOff))
        case .neutral:
            .init(kind: .neutral, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateNeutral))
        case .on:
            .init(kind: .on, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateOn))
        case .charging:
            .init(kind: .charging, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateCharging))
        case .crawlForward:
            .init(kind: .crawlForward, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateCrawlForward))
        case .crawlReverse:
            .init(kind: .crawlReverse, title: BikeDiagnosticsL10n.text(.bikeDiagnosticsStateCrawlReverse))
        }
    }
}
