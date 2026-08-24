import Foundation

public struct SystemTimeFormatter: Sendable {
    private static let diagnosticsStyle = Date.FormatStyle()
        .hour(.twoDigits(amPM: .omitted))
        .minute(.twoDigits)
        .second(.twoDigits)

    public init() {}

    public func diagnosticsTime(from date: Date) -> String {
        date.formatted(Self.diagnosticsStyle)
    }

    public func standardTime(from date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }
}
