import Foundation

public struct BikeDiagnosticsDateFormatter: Sendable {
    private static let formatStyle = Date.FormatStyle()
        .hour(.twoDigits(amPM: .omitted))
        .minute(.twoDigits)
        .second(.twoDigits)

    public init() {}

    public func string(from date: Date) -> String {
        date.formatted(Self.formatStyle)
    }
}
