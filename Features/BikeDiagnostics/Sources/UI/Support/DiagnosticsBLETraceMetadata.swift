import UIKit

enum DiagnosticsBLETraceMetadata {
    static func copy(_ session: BLETraceSessionViewData) {
        UIPasteboard.general.string = text(for: session)
    }

    static func text(for session: BLETraceSessionViewData) -> String {
        [
            "\(DiagnosticsCopy.started): \(session.date)",
            "\(DiagnosticsCopy.status): \(session.status)",
            "\(DiagnosticsCopy.duration): \(session.duration)",
            "\(DiagnosticsCopy.size): \(session.size)",
            "\(DiagnosticsCopy.eventCount): \(session.eventCount)"
        ].joined(separator: "\n")
    }
}
