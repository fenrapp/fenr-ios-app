public struct BikeDiagnosticsViewState: Equatable, Sendable {
    public var vin: String
    public var connection: ConnectionPanelViewData
    public var overviewMetrics: [BikeDiagnosticsMetricViewData]
    public var metrics: [BikeDiagnosticsMetricViewData]
    public var powerMetrics: [BikeDiagnosticsMetricViewData]
    public var batteryMetrics: [BikeDiagnosticsMetricViewData]
    public var badges: [BikeDiagnosticsBadgeViewData]
    public var rawFlags: [BikeDiagnosticsMetricViewData]
    public var telemetrySections: [BikeDiagnosticsSectionViewData]
    public var powerModeConfigurations: [BikeDiagnosticsPowerModeViewData]
    public var decodedStatus: [BikeDiagnosticsMetricViewData]
    public var debugEvents: [DebugEventViewData]
    public var hasDebugLog: Bool
    public var bleTraceSessions: [BLETraceSessionViewData]
    public var bleTraceError: String?
    public var isReconnectEnabled: Bool
    public var isDisconnectEnabled: Bool
    public var isPairRetryEnabled: Bool
    public var isReadSnapshotEnabled: Bool
    public var isBatteryHealthEnabled: Bool

    public static var defaultConnection: ConnectionPanelViewData {
        .init(
            status: BikeDiagnosticsText.idle,
            detail: BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionDetailChooseBike),
            rssi: BikeDiagnosticsText.emptyRSSI,
            configuredVIN: BikeDiagnosticsText.placeholder,
            peripheralName: BikeDiagnosticsText.noPeripheral,
            peripheralIdentifier: BikeDiagnosticsText.placeholder
        )
    }

    public init(
        vin: String = "",
        connection: ConnectionPanelViewData = BikeDiagnosticsViewState.defaultConnection,
        overviewMetrics: [BikeDiagnosticsMetricViewData] = [],
        metrics: [BikeDiagnosticsMetricViewData] = [],
        powerMetrics: [BikeDiagnosticsMetricViewData] = [],
        batteryMetrics: [BikeDiagnosticsMetricViewData] = [],
        badges: [BikeDiagnosticsBadgeViewData] = [],
        rawFlags: [BikeDiagnosticsMetricViewData] = [],
        telemetrySections: [BikeDiagnosticsSectionViewData] = [],
        powerModeConfigurations: [BikeDiagnosticsPowerModeViewData] = [],
        decodedStatus: [BikeDiagnosticsMetricViewData] = [],
        debugEvents: [DebugEventViewData] = [],
        hasDebugLog: Bool = false,
        bleTraceSessions: [BLETraceSessionViewData] = [],
        bleTraceError: String? = nil,
        isReconnectEnabled: Bool = false,
        isDisconnectEnabled: Bool = false,
        isPairRetryEnabled: Bool = false,
        isReadSnapshotEnabled: Bool = false,
        isBatteryHealthEnabled: Bool = false
    ) {
        self.vin = vin
        self.connection = connection
        self.overviewMetrics = overviewMetrics
        self.metrics = metrics
        self.powerMetrics = powerMetrics
        self.batteryMetrics = batteryMetrics
        self.badges = badges
        self.rawFlags = rawFlags
        self.telemetrySections = telemetrySections
        self.powerModeConfigurations = powerModeConfigurations
        self.decodedStatus = decodedStatus
        self.debugEvents = debugEvents
        self.hasDebugLog = hasDebugLog
        self.bleTraceSessions = bleTraceSessions
        self.bleTraceError = bleTraceError
        self.isReconnectEnabled = isReconnectEnabled
        self.isDisconnectEnabled = isDisconnectEnabled
        self.isPairRetryEnabled = isPairRetryEnabled
        self.isReadSnapshotEnabled = isReadSnapshotEnabled
        self.isBatteryHealthEnabled = isBatteryHealthEnabled
    }
}
