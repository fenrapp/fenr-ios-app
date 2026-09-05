import BLETraceDomain

public struct BLETraceFailureViewDataMapper: Sendable {
    public init() {}

    public func map(_ failure: BLETraceRecordingFailure?) -> String? {
        guard let failure else { return nil }
        return switch failure.phase {
        case .preparing:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsBleLogLoadError)
        case .opening, .writing, .finishing:
            BikeDiagnosticsL10n.text(.bikeDiagnosticsBleRecordingWriteError)
        }
    }
}
