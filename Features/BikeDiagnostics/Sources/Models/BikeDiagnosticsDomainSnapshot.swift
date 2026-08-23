import BikeDomain

struct BikeDiagnosticsDomainSnapshot: Sendable {
    var vin: String
    var pin: String
    var telemetry: BikeTelemetry
    var connection: BikeConnection
    var debugEvents: [BikeDebugEvent]

    init(
        vin: String = "",
        pin: String = BikeDiagnosticsText.placeholderPIN,
        telemetry: BikeTelemetry = BikeTelemetry(),
        connection: BikeConnection = BikeConnection(),
        debugEvents: [BikeDebugEvent] = []
    ) {
        self.vin = vin
        self.pin = pin
        self.telemetry = telemetry
        self.connection = connection
        self.debugEvents = debugEvents
    }
}
