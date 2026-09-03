import BikeDomain
import Foundation

public struct BatteryHealthCaptureFormatter: Sendable {
    private let dateFormatStyle: Date.FormatStyle

    public init(dateFormatStyle: Date.FormatStyle) {
        self.dateFormatStyle = dateFormatStyle
    }

    public func timestamp(_ date: Date?) -> String? {
        date.map { $0.formatted(dateFormatStyle) }
    }

    public func export(
        captures: [BatteryDataset: BatteryDatasetCapture],
        chargeAuditLines: [String]
    ) -> String {
        let captureLines = captures.values
            .sorted { $0.date > $1.date }
            .map { capture in
                "\(capture.date.formatted(dateFormatStyle)) | "
                    + "\(capture.dataset.displayName) | \(capture.byteCount) B | \(capture.hex)"
            }
        let chargeLines = chargeAuditLines.map { "ChargeControl | \($0)" }
        return (chargeLines + captureLines).joined(separator: "\n")
    }
}
