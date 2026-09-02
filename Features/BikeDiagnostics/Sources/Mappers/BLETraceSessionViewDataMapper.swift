import BLETraceDomain
import Foundation

public struct BLETraceSessionViewDataMapper: Sendable {
    private let dateFormatStyle: Date.FormatStyle
    private let byteCountFormatStyle: ByteCountFormatStyle

    public init(
        dateFormatStyle: Date.FormatStyle,
        byteCountFormatStyle: ByteCountFormatStyle
    ) {
        self.dateFormatStyle = dateFormatStyle
        self.byteCountFormatStyle = byteCountFormatStyle
    }

    public func map(_ session: BLETraceSessionSummary) -> BLETraceSessionViewData {
        BLETraceSessionViewData(
            id: session.id,
            date: session.startedAt.formatted(dateFormatStyle),
            duration: durationText(session.duration),
            size: session.fileSizeBytes.formatted(byteCountFormatStyle),
            status: statusText(session.status),
            statusKind: statusKind(session.status),
            isActive: session.status == .active,
            canDelete: session.status != .active
        )
    }

    private func durationText(_ duration: TimeInterval?) -> String {
        guard let duration else { return BikeDiagnosticsL10n.text(.bikeDiagnosticsBleStatusRecording) }
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return minutes > 0
            ? BikeDiagnosticsL10n.text(.bikeDiagnosticsBleDurationMinutes(minutes, seconds))
            : BikeDiagnosticsL10n.text(.bikeDiagnosticsBleDurationSeconds(seconds))
    }

    private func statusText(_ status: BLETraceSessionStatus) -> String {
        switch status {
        case .active: BikeDiagnosticsL10n.text(.bikeDiagnosticsBleStatusRecording)
        case .complete: BikeDiagnosticsL10n.text(.bikeDiagnosticsBleStatusComplete)
        case .incomplete: BikeDiagnosticsL10n.text(.bikeDiagnosticsBleStatusIncomplete)
        case .truncated: BikeDiagnosticsL10n.text(.bikeDiagnosticsBleStatusTruncated)
        }
    }

    private func statusKind(_ status: BLETraceSessionStatus) -> BLETraceSessionViewData.Status {
        switch status {
        case .active: .recording
        case .complete: .complete
        case .incomplete: .incomplete
        case .truncated: .truncated
        }
    }
}
