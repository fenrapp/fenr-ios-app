import Foundation
import MeasurementPresentation

public struct BikeDiagnosticsDateFormatter: Sendable {
    private let formatter: SystemTimeFormatter

    public init(formatter: SystemTimeFormatter = .init()) {
        self.formatter = formatter
    }

    public func string(from date: Date) -> String {
        formatter.diagnosticsTime(from: date)
    }
}
