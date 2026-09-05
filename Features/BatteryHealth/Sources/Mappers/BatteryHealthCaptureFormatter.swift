import BikeDomain
import Foundation

public struct BatteryHealthCaptureFormatter: Sendable {
    private let dateFormatStyle: Date.FormatStyle
    private let isDemo: Bool

    public init(dateFormatStyle: Date.FormatStyle, isDemo: Bool = false) {
        self.dateFormatStyle = dateFormatStyle
        self.isDemo = isDemo
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
        let header = isDemo ? ["FENR DEMO - Simulated motorcycle data"] : []
        return (header + chargeLines + captureLines).joined(separator: "\n")
    }
}
