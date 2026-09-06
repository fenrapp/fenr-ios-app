import BikeDomain
import Foundation
import VehicleSession

@MainActor
public struct BikeTelemetryToBikeDiagnosticsViewStateMapper {
    private let connectionMapper: BikeConnectionToConnectionPanelMapper
    private let metricsMapper: BikeTelemetryToMetricsMapper
    private let powerMetricsMapper: BikePowerTelemetryToMetricsMapper
    private let batteryMetricsMapper: BikeBatteryTelemetryToMetricsMapper
    private let badgesMapper: BikeTelemetryToBadgesMapper
    private let rawFlagsMapper: BikeTelemetryToRawFlagsMapper
    private let debugEventMapper: BikeDebugEventToDebugEventViewDataMapper
    private let speedFormatter: BikeDiagnosticsSpeedFormatter
    private let isDemo: Bool

    public init(
        connectionMapper: BikeConnectionToConnectionPanelMapper,
        metricsMapper: BikeTelemetryToMetricsMapper,
        powerMetricsMapper: BikePowerTelemetryToMetricsMapper,
        batteryMetricsMapper: BikeBatteryTelemetryToMetricsMapper,
        badgesMapper: BikeTelemetryToBadgesMapper,
        rawFlagsMapper: BikeTelemetryToRawFlagsMapper,
        debugEventMapper: BikeDebugEventToDebugEventViewDataMapper,
        speedFormatter: BikeDiagnosticsSpeedFormatter,
        isDemo: Bool = false
    ) {
        self.connectionMapper = connectionMapper
        self.metricsMapper = metricsMapper
        self.powerMetricsMapper = powerMetricsMapper
        self.batteryMetricsMapper = batteryMetricsMapper
        self.badgesMapper = badgesMapper
        self.rawFlagsMapper = rawFlagsMapper
        self.debugEventMapper = debugEventMapper
        self.speedFormatter = speedFormatter
        self.isDemo = isDemo
    }

    public func map(
        _ snapshot: VehicleSessionSnapshot,
        debugEvents: [BikeDebugEvent]
    ) -> BikeDiagnosticsViewState {
        let telemetry = snapshot.telemetry
        let profileVIN = snapshot.profile?.vin
        let metrics = metricsMapper.map(telemetry)
        let batteryMetrics = batteryMetricsMapper.map(telemetry.batteryTelemetry)
        let rawFlags = rawFlagsMapper.map(telemetry)
        let visibleEvents = debugEvents
            .prefix(BikeDiagnosticsConstants.maxVisibleDebugEvents)
            .map(debugEventMapper.map)

        return BikeDiagnosticsViewState(
            vin: profileVIN ?? BikeDiagnosticsText.placeholder,
            connection: connectionMapper.map(
                snapshot.connection, configuredVIN: profileVIN,
                presentationName: isDemo ? String(localized: .bikeDiagnosticsDemoBikeName) : nil
            ),
            overviewMetrics: overviewMetrics(telemetry),
            metrics: metrics,
            batteryMetrics: batteryMetrics,
            badges: badgesMapper.map(telemetry),
            rawFlags: rawFlags,
            telemetrySections: telemetrySections(snapshot: snapshot),
            powerModeConfigurations: powerModeConfigurations(telemetry),
            decodedStatus: decodedStatus(telemetry.statusFlags),
            debugEvents: visibleEvents,
            hasDebugLog: hasDebugLog(snapshot, debugEvents: debugEvents),
            isReconnectEnabled: connectionMapper.isReconnectEnabled(
                snapshot.connection,
                configuredVIN: profileVIN
            ),
            isDisconnectEnabled: connectionMapper.isDisconnectEnabled(snapshot.connection),
            isPairRetryEnabled: connectionMapper.isPairRetryEnabled(snapshot.connection),
            isReadSnapshotEnabled: connectionMapper.isReadSnapshotEnabled(snapshot.connection),
            isBatteryHealthEnabled: connectionMapper.isBatteryHealthEnabled(snapshot.connection)
        )
    }

    public func exportDebugLog(
        _ snapshot: VehicleSessionSnapshot,
        events: [BikeDebugEvent]
    ) -> String {
        let sectionLines = telemetrySections(snapshot: snapshot).flatMap { section in
            ["[\(section.title)]"] + section.metrics.map(exportMetric)
        }
        let statusLines = ["[Decoded Status]"]
            + decodedStatus(snapshot.telemetry.statusFlags).map(exportMetric)
        let rawLines = ["[Raw Status]"] + rawFlagsMapper.map(snapshot.telemetry).map(exportMetric)
        let eventLines = ["[Events]"] + events.map(debugEventMapper.exportLine)
        let header = isDemo ? ["FENR DEMO - Simulated motorcycle data"] : []
        return (header + sectionLines + statusLines + rawLines + eventLines)
            .joined(separator: BikeDiagnosticsConstants.debugLogLineSeparator)
    }

    private func overviewMetrics(_ telemetry: BikeTelemetry) -> [BikeDiagnosticsMetricViewData] {
        let core = metricsMapper.map(telemetry)
        let power = powerMetricsMapper.map(telemetry.powerTelemetry)
        return [
            metric(from: core, id: "mode"),
            metric(from: core, id: "speed"),
            metric(from: power, id: "electricalPower"),
            metric(from: core, id: "battery"),
            metric(from: core, id: "soh"),
            .init(
                id: "alerts",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricAlerts),
                value: alertSummary(telemetry)
            )
        ]
    }
}

private extension BikeTelemetryToBikeDiagnosticsViewStateMapper {
    private func telemetrySections(snapshot: VehicleSessionSnapshot) -> [BikeDiagnosticsSectionViewData] {
        let telemetry = snapshot.telemetry
        return [
            .init(
                id: "vehicle",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionVehicle),
                metrics: vehicleMetrics(snapshot)
            ),
            .init(
                id: "live",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionLiveTelemetry),
                metrics: metricsMapper.map(telemetry)
            ),
            .init(
                id: "power",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionPower),
                metrics: powerMetricsMapper.map(telemetry.powerTelemetry)
            ),
            .init(
                id: "battery",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionBattery),
                metrics: batteryMetricsMapper.map(telemetry.batteryTelemetry)
            ),
            .init(
                id: "temperatures",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionInverterTemperatures),
                metrics: temperatureMetrics(telemetry)
            ),
            .init(
                id: "configurations",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionPowerModeConfigurations),
                metrics: configurationMetrics(telemetry),
                style: .powerModes
            ),
            .init(
                id: "powerTier",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionPowerTierEvidence),
                metrics: powerTierMetrics(snapshot),
                style: .powerTier
            )
        ]
    }

    private func vehicleMetrics(_ snapshot: VehicleSessionSnapshot) -> [BikeDiagnosticsMetricViewData] {
        let telemetry = snapshot.telemetry
        return [
            .init(
                id: "configuredVIN",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricConfiguredIdentity),
                value: snapshot.profile?.vin ?? BikeDiagnosticsText.placeholder
            ),
            .init(
                id: "reportedVIN",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricReportedIdentity),
                value: telemetry.vin.isEmpty ? BikeDiagnosticsText.placeholder : telemetry.vin
            ),
            .init(
                id: "variant",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricVariant),
                value: variantText(snapshot.profile?.variant)
            ),
            .init(
                id: "odometer",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricOdometer),
                value: odometerText(telemetry.odometer)
            ),
            .init(
                id: "rpm",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricMotorRpm),
                value: telemetry.motorRPM.value.map(String.init) ?? BikeDiagnosticsText.placeholder
            ),
            .init(
                id: "updated",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricLastUpdate),
                value: telemetry.lastUpdated?.formatted() ?? BikeDiagnosticsText.placeholder
            )
        ]
    }

    private func temperatureMetrics(_ telemetry: BikeTelemetry) -> [BikeDiagnosticsMetricViewData] {
        let count = max(
            telemetry.inverterTemperatureRawValues.count,
            telemetry.inverterTemperaturesCelsius.count
        )
        guard count > 0 else {
            return [.init(
                id: "temperatureUnavailable",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricSensors),
                value: BikeDiagnosticsText.placeholder
            )]
        }
        return (0..<count).map { index in
            let raw = telemetry.inverterTemperatureRawValues[safe: index].map(String.init)
                ?? BikeDiagnosticsText.placeholder
            let temperature = telemetry.inverterTemperaturesCelsius[safe: index].flatMap { $0 }
            let value = temperature.map(speedFormatter.temperature) ?? BikeDiagnosticsText.placeholder
            return .init(
                id: "inverterTemperature\(index)",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricSensor(index + 1)),
                value: "\(value) (raw \(raw))"
            )
        }
    }

    private func decodedStatus(_ flags: BikeStatusFlags) -> [BikeDiagnosticsMetricViewData] {
        [
            statusMetric("runState", .bikeDiagnosticsMetricRunState, runStateText(flags)),
            statusMetric("powerOn", .bikeDiagnosticsMetricPower, booleanText(flags.isOn)),
            statusMetric("charging", .bikeDiagnosticsMetricCharging, booleanText(flags.isCharging)),
            statusMetric(
                "chargerConnected",
                .bikeDiagnosticsMetricChargerConnected,
                booleanText(flags.isChargerConnected)
            ),
            statusMetric("inGear", .bikeDiagnosticsMetricInGear, booleanText(flags.isInGear)),
            statusMetric("fault", .bikeDiagnosticsMetricFaultActive, booleanText(flags.isFaultActive)),
            statusMetric("brake", .bikeDiagnosticsMetricBrakeActive, booleanText(flags.isBrakeActive)),
            statusMetric("crawl", .bikeDiagnosticsMetricCrawl, crawlText(flags.crawlState)),
            statusMetric(
                "highBeam",
                .bikeDiagnosticsMetricHighBeam,
                booleanText(flags.indicatorState.isHighBeamOn)
            ),
            statusMetric(
                "leftBlinker",
                .bikeDiagnosticsMetricLeftIndicator,
                booleanText(flags.indicatorState.isLeftBlinkerOn)
            ),
            statusMetric(
                "rightBlinker",
                .bikeDiagnosticsMetricRightIndicator,
                booleanText(flags.indicatorState.isRightBlinkerOn)
            ),
            statusMetric(
                "checkEngine",
                .bikeDiagnosticsMetricCheckEngine,
                booleanText(flags.indicatorState.isCheckEngineLightOn)
            )
        ]
    }

    private func statusMetric(
        _ id: String,
        _ title: LocalizedStringResource,
        _ value: String
    ) -> BikeDiagnosticsMetricViewData {
        .init(id: id, title: BikeDiagnosticsL10n.text(title), value: value)
    }

    private func hasDebugLog(_ snapshot: VehicleSessionSnapshot, debugEvents: [BikeDebugEvent]) -> Bool {
        !debugEvents.isEmpty
            || snapshot.telemetry.lastUpdated != nil
            || snapshot.telemetry.powerTelemetry.calculatedPowerUpdatedAt != nil
            || snapshot.telemetry.batteryTelemetry.stateUpdatedAt != nil
            || snapshot.telemetry.batteryTelemetry.signalsUpdatedAt != nil
    }

    private func exportMetric(_ metric: BikeDiagnosticsMetricViewData) -> String {
        let qualifier = metric.verification == .confirmed ? "" : " [\(metric.verification.title)]"
        return "\(metric.title)\(qualifier)=\(metric.value)"
    }

    private func metric(
        from metrics: [BikeDiagnosticsMetricViewData],
        id: String
    ) -> BikeDiagnosticsMetricViewData {
        metrics.first(where: { $0.id == id })
            ?? .init(
                id: id,
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricUnavailable),
                value: BikeDiagnosticsText.placeholder
            )
    }

    private func alertSummary(_ telemetry: BikeTelemetry) -> String {
        let count = [telemetry.rawStatusFlags.alert, telemetry.rawStatusFlags.fault]
            .filter { $0 != 0 }
            .count
        return telemetry.statusFlags.isFaultActive || count > 0
            ? BikeDiagnosticsL10n.text(.bikeDiagnosticsValueAttention(count))
            : BikeDiagnosticsL10n.text(.bikeDiagnosticsValueNone)
    }

    private func odometerText(_ odometer: BikeOdometer) -> String {
        odometer.kilometers.map(speedFormatter.distance) ?? BikeDiagnosticsText.placeholder
    }

    private func variantText(_ variant: BikeVariant?) -> String {
        switch variant {
        case .mx: "MX"
        case .ex: "EX"
        case .sm: "SM"
        case .unknown: BikeDiagnosticsText.unknown
        case nil: BikeDiagnosticsText.placeholder
        }
    }

    private func runStateText(_ flags: BikeStatusFlags) -> String {
        if flags == .unknown { return BikeDiagnosticsText.unknown }
        if flags.crawlState == .forward {
            return BikeDiagnosticsL10n.text(.bikeDiagnosticsValueCrawlForward)
        }
        if flags.crawlState == .reverse {
            return BikeDiagnosticsL10n.text(.bikeDiagnosticsValueCrawlReverse)
        }
        if flags.isCharging { return BikeDiagnosticsL10n.text(.bikeDiagnosticsStateCharging) }
        if flags.isInGear { return BikeDiagnosticsL10n.text(.bikeDiagnosticsStateOn) }
        if flags.isOn { return BikeDiagnosticsL10n.text(.bikeDiagnosticsStateNeutral) }
        return BikeDiagnosticsL10n.text(.bikeDiagnosticsStateOff)
    }

    private func crawlText(_ state: BikeCrawlState) -> String {
        switch state {
        case .inactive: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueInactive)
        case .forward: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueForward)
        case .reverse: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueReverse)
        case .unknown: BikeDiagnosticsText.unknown
        }
    }

    private func booleanText(_ value: Bool) -> String {
        value
            ? BikeDiagnosticsL10n.text(.bikeDiagnosticsValueYes)
            : BikeDiagnosticsL10n.text(.bikeDiagnosticsValueNo)
    }
}
