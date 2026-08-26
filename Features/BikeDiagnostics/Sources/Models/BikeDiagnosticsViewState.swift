public struct BikeDiagnosticsViewState: Equatable, Sendable {
    public var vin: String
    public var pin: String
    public var connection: ConnectionPanelViewData
    public var metrics: [BikeDiagnosticsMetricViewData]
    public var powerMetrics: [BikeDiagnosticsMetricViewData]
    public var batteryMetrics: [BikeDiagnosticsMetricViewData]
    public var badges: [String]
    public var rawFlags: [BikeDiagnosticsMetricViewData]
    public var debugEvents: [DebugEventViewData]
    public var hasDebugLog: Bool
    public var isVINEditingEnabled: Bool
    public var isConnectEnabled: Bool
    public var isDisconnectEnabled: Bool
    public var isPairRetryEnabled: Bool
    public var isReadSnapshotEnabled: Bool
    public var isBatteryHealthEnabled: Bool

    public init(
        vin: String = "",
        pin: String = BikeDiagnosticsText.placeholderPIN,
        connection: ConnectionPanelViewData = .init(
            status: BikeDiagnosticsText.idle,
            detail: BikeDiagnosticsText.enterVINToConnect,
            rssi: BikeDiagnosticsText.emptyRSSI,
            peripheral: BikeDiagnosticsText.noPeripheral
        ),
        metrics: [BikeDiagnosticsMetricViewData] = [],
        powerMetrics: [BikeDiagnosticsMetricViewData] = [],
        batteryMetrics: [BikeDiagnosticsMetricViewData] = [],
        badges: [String] = [],
        rawFlags: [BikeDiagnosticsMetricViewData] = [],
        debugEvents: [DebugEventViewData] = [],
        hasDebugLog: Bool = false,
        isVINEditingEnabled: Bool = true,
        isConnectEnabled: Bool = false,
        isDisconnectEnabled: Bool = false,
        isPairRetryEnabled: Bool = false,
        isReadSnapshotEnabled: Bool = false,
        isBatteryHealthEnabled: Bool = false
    ) {
        self.vin = vin
        self.pin = pin
        self.connection = connection
        self.metrics = metrics
        self.powerMetrics = powerMetrics
        self.batteryMetrics = batteryMetrics
        self.badges = badges
        self.rawFlags = rawFlags
        self.debugEvents = debugEvents
        self.hasDebugLog = hasDebugLog
        self.isVINEditingEnabled = isVINEditingEnabled
        self.isConnectEnabled = isConnectEnabled
        self.isDisconnectEnabled = isDisconnectEnabled
        self.isPairRetryEnabled = isPairRetryEnabled
        self.isReadSnapshotEnabled = isReadSnapshotEnabled
        self.isBatteryHealthEnabled = isBatteryHealthEnabled
    }
}
