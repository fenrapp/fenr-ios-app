import Foundation

public enum BikeDiagnosticsDestination: String, CaseIterable, Hashable, Sendable {
    case overview
    case connection
    case telemetry
    case status
    case events
    case bleLogs

    public var title: String {
        switch self {
        case .overview: BikeDiagnosticsL10n.text(.bikeDiagnosticsDestinationOverview)
        case .connection: BikeDiagnosticsL10n.text(.bikeDiagnosticsDestinationConnection)
        case .telemetry: BikeDiagnosticsL10n.text(.bikeDiagnosticsDestinationTelemetry)
        case .status: BikeDiagnosticsL10n.text(.bikeDiagnosticsDestinationStatus)
        case .events: BikeDiagnosticsL10n.text(.bikeDiagnosticsDestinationEvents)
        case .bleLogs: BikeDiagnosticsL10n.text(.bikeDiagnosticsDestinationBleLogs)
        }
    }
}
