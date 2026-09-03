import Foundation

public struct BikeDiagnosticsMetricViewData: Equatable, Identifiable, Sendable {
    public enum Verification: Equatable, Sendable {
        case confirmed
        case candidate
        case unverified

        public var title: String {
            switch self {
            case .confirmed: BikeDiagnosticsL10n.text(.bikeDiagnosticsVerificationConfirmed)
            case .candidate: BikeDiagnosticsL10n.text(.bikeDiagnosticsVerificationCandidate)
            case .unverified: BikeDiagnosticsL10n.text(.bikeDiagnosticsVerificationUnverified)
            }
        }
    }

    public let id: String
    public let title: String
    public let value: String
    public let verification: Verification

    public init(
        id: String,
        title: String,
        value: String,
        verification: Verification = .confirmed
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.verification = verification
    }
}
