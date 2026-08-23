import BikeDomain
import Foundation

@MainActor
public struct BikeTelemetryToMetricsMapper {
    private let dateFormatter: BikeDiagnosticsDateFormatter
    private let speedFormatter: BikeDiagnosticsSpeedFormatter
    private let percentFormatter: BikeDiagnosticsPercentFormatter

    public init(
        dateFormatter: BikeDiagnosticsDateFormatter,
        speedFormatter: BikeDiagnosticsSpeedFormatter,
        percentFormatter: BikeDiagnosticsPercentFormatter
    ) {
        self.dateFormatter = dateFormatter
        self.speedFormatter = speedFormatter
        self.percentFormatter = percentFormatter
    }

    public func map(_ telemetry: BikeTelemetry) -> [BikeDiagnosticsMetricViewData] {
        [
            .init(id: "battery", title: "Battery", value: percentText(telemetry.batteryLevel.percent)),
            .init(id: "soh", title: "SOH", value: percentText(telemetry.healthLevel.percent)),
            .init(id: "mode", title: "Mode", value: modeText(telemetry.mode)),
            .init(id: "speed", title: "Speed", value: speedText(telemetry.speed)),
            .init(id: "rpm", title: "Motor RPM", value: rpmText(telemetry.motorRPM)),
            .init(id: "updated", title: "Updated", value: updatedText(telemetry.lastUpdated))
        ]
    }

    private func percentText(_ value: Int?) -> String {
        value.map(percentFormatter.string) ?? BikeDiagnosticsText.placeholder
    }

    private func modeText(_ mode: BikeMode) -> String {
        mode.displayIndex.map(String.init) ?? BikeDiagnosticsText.placeholder
    }

    private func speedText(_ speed: BikeSpeed) -> String {
        speed.kmh.map(speedFormatter.string) ?? BikeDiagnosticsText.placeholder
    }

    private func rpmText(_ rpm: MotorRPM) -> String {
        rpm.value.map(String.init) ?? BikeDiagnosticsText.placeholder
    }

    private func updatedText(_ date: Date?) -> String {
        date.map(dateFormatter.string(from:)) ?? BikeDiagnosticsText.placeholder
    }
}
