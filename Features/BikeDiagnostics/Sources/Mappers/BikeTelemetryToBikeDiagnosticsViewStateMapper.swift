import BikeDomain

@MainActor
public struct BikeTelemetryToBikeDiagnosticsViewStateMapper {
    private let connectionMapper: BikeConnectionToConnectionPanelMapper
    private let metricsMapper: BikeTelemetryToMetricsMapper
    private let powerMetricsMapper: BikePowerTelemetryToMetricsMapper
    private let batteryMetricsMapper: BikeBatteryTelemetryToMetricsMapper
    private let badgesMapper: BikeTelemetryToBadgesMapper
    private let rawFlagsMapper: BikeTelemetryToRawFlagsMapper
    private let debugEventMapper: BikeDebugEventToDebugEventViewDataMapper

    public init(
        connectionMapper: BikeConnectionToConnectionPanelMapper,
        metricsMapper: BikeTelemetryToMetricsMapper,
        powerMetricsMapper: BikePowerTelemetryToMetricsMapper,
        batteryMetricsMapper: BikeBatteryTelemetryToMetricsMapper,
        badgesMapper: BikeTelemetryToBadgesMapper,
        rawFlagsMapper: BikeTelemetryToRawFlagsMapper,
        debugEventMapper: BikeDebugEventToDebugEventViewDataMapper
    ) {
        self.connectionMapper = connectionMapper
        self.metricsMapper = metricsMapper
        self.powerMetricsMapper = powerMetricsMapper
        self.batteryMetricsMapper = batteryMetricsMapper
        self.badgesMapper = badgesMapper
        self.rawFlagsMapper = rawFlagsMapper
        self.debugEventMapper = debugEventMapper
    }

    func map(_ snapshot: BikeDiagnosticsDomainSnapshot) -> BikeDiagnosticsViewState {
        let debugEvents = snapshot.debugEvents
            .prefix(BikeDiagnosticsConstants.maxVisibleDebugEvents)
            .map(debugEventMapper.map)

        return BikeDiagnosticsViewState(
            vin: snapshot.vin,
            pin: snapshot.pin,
            connection: connectionMapper.map(snapshot.connection),
            metrics: metricsMapper.map(snapshot.telemetry),
            powerMetrics: powerMetricsMapper.map(snapshot.telemetry.powerTelemetry),
            batteryMetrics: batteryMetricsMapper.map(snapshot.telemetry.batteryTelemetry),
            badges: badgesMapper.map(snapshot.telemetry),
            rawFlags: rawFlagsMapper.map(snapshot.telemetry),
            debugEvents: debugEvents,
            hasDebugLog: hasDebugLog(snapshot),
            isVINEditingEnabled: connectionMapper.isVINEditingEnabled(snapshot.connection),
            isConnectEnabled: !snapshot.vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            isDisconnectEnabled: connectionMapper.isDisconnectEnabled(snapshot.connection),
            isPairRetryEnabled: connectionMapper.isPairRetryEnabled(snapshot.connection),
            isReadSnapshotEnabled: connectionMapper.isReadSnapshotEnabled(snapshot.connection),
            isBatteryHealthEnabled: connectionMapper.isBatteryHealthEnabled(snapshot.connection)
        )
    }

    func exportDebugLog(_ snapshot: BikeDiagnosticsDomainSnapshot, events: [BikeDebugEvent]) -> String {
        let snapshotLines = ["[Power Telemetry]"]
            + powerMetricsMapper.map(snapshot.telemetry.powerTelemetry).map { "\($0.title)=\($0.value)" }
            + ["[Battery Telemetry]"]
            + batteryMetricsMapper.map(snapshot.telemetry.batteryTelemetry).map { "\($0.title)=\($0.value)" }
            + ["[Events]"]
        let eventLines = events
            .map(debugEventMapper.exportLine)
        return (snapshotLines + eventLines)
            .joined(separator: BikeDiagnosticsConstants.debugLogLineSeparator)
    }

    private func hasDebugLog(_ snapshot: BikeDiagnosticsDomainSnapshot) -> Bool {
        !snapshot.debugEvents.isEmpty
            || snapshot.telemetry.powerTelemetry.calculatedPowerUpdatedAt != nil
            || snapshot.telemetry.batteryTelemetry.stateUpdatedAt != nil
            || snapshot.telemetry.batteryTelemetry.signalsUpdatedAt != nil
    }
}
