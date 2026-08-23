import BikeDomain

public struct BikeDebugEventToDebugEventViewDataMapper: Sendable {
    private let dateFormatter: BikeDiagnosticsDateFormatter

    public init(dateFormatter: BikeDiagnosticsDateFormatter) {
        self.dateFormatter = dateFormatter
    }

    public func map(_ event: BikeDebugEvent) -> DebugEventViewData {
        DebugEventViewData(
            id: event.id,
            time: dateFormatter.string(from: event.date),
            title: event.title,
            detail: event.detail
        )
    }

    public func exportLine(_ event: BikeDebugEvent) -> String {
        [
            dateFormatter.string(from: event.date),
            event.title,
            event.detail
        ].joined(separator: BikeDiagnosticsConstants.debugLogSeparator)
    }
}
