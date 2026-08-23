import BikeDomain

@MainActor
public struct BikeTelemetryToBikeDiagnosticsViewStateMapper {
    private let connectionMapper: BikeConnectionToConnectionPanelMapper
    private let metricsMapper: BikeTelemetryToMetricsMapper
    private let badgesMapper: BikeTelemetryToBadgesMapper
    private let rawFlagsMapper: BikeTelemetryToRawFlagsMapper
    private let debugEventMapper: BikeDebugEventToDebugEventViewDataMapper

    public init(
        connectionMapper: BikeConnectionToConnectionPanelMapper,
        metricsMapper: BikeTelemetryToMetricsMapper,
        badgesMapper: BikeTelemetryToBadgesMapper,
        rawFlagsMapper: BikeTelemetryToRawFlagsMapper,
        debugEventMapper: BikeDebugEventToDebugEventViewDataMapper
    ) {
        self.connectionMapper = connectionMapper
        self.metricsMapper = metricsMapper
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
            badges: badgesMapper.map(snapshot.telemetry),
            rawFlags: rawFlagsMapper.map(snapshot.telemetry),
            debugEvents: debugEvents,
            hasDebugLog: !snapshot.debugEvents.isEmpty,
            isVINEditingEnabled: connectionMapper.isVINEditingEnabled(snapshot.connection),
            isConnectEnabled: !snapshot.vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            isDisconnectEnabled: connectionMapper.isDisconnectEnabled(snapshot.connection),
            isPairRetryEnabled: connectionMapper.isPairRetryEnabled(snapshot.connection),
            isReadSnapshotEnabled: connectionMapper.isReadSnapshotEnabled(snapshot.connection),
            isBatteryHealthEnabled: connectionMapper.isBatteryHealthEnabled(snapshot.connection)
        )
    }

    func exportDebugLog(_ events: [BikeDebugEvent]) -> String {
        events
            .map(debugEventMapper.exportLine)
            .joined(separator: BikeDiagnosticsConstants.debugLogLineSeparator)
    }
}
