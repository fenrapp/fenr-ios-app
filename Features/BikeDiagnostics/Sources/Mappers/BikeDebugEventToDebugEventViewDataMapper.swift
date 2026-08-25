import BikeDomain
import Foundation

public struct BikeDebugEventToDebugEventViewDataMapper: Sendable {
    private let dateFormatStyle: Date.FormatStyle

    public init(dateFormatStyle: Date.FormatStyle) {
        self.dateFormatStyle = dateFormatStyle
    }

    public func map(_ event: BikeDebugEvent) -> DebugEventViewData {
        DebugEventViewData(
            id: event.id,
            time: event.date.formatted(dateFormatStyle),
            title: event.title,
            detail: event.detail
        )
    }

    public func exportLine(_ event: BikeDebugEvent) -> String {
        [
            event.date.formatted(dateFormatStyle),
            event.title,
            event.detail
        ].joined(separator: BikeDiagnosticsConstants.debugLogSeparator)
    }
}
