import BikeDomain
import Foundation

public struct BikeTelemetryToRawFlagsMapper: Sendable {
    public init() {}

    public func map(_ telemetry: BikeTelemetry) -> [BikeDiagnosticsMetricViewData] {
        let flags = telemetry.rawStatusFlags
        return [
            .init(id: "misc", title: "miscBits", value: hexText(flags.misc)),
            .init(id: "indicator", title: "indicatorBits", value: hexText(flags.indicator)),
            .init(id: "alert", title: "alertBits", value: hexText(flags.alert)),
            .init(id: "fault", title: "faultBits", value: hexText(flags.fault)),
            .init(id: "info", title: "infoBits", value: hexText(flags.info))
        ]
    }

    private func hexText(_ value: Int) -> String {
        String(format: BikeDiagnosticsConstants.hex16Format, value)
    }
}
