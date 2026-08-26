import BikeDomain

public actor BikeRepositoryStateStore {
    private var telemetry = BikeTelemetry()
    private var connection = BikeConnection()

    public init() {}

    public func currentTelemetry() -> BikeTelemetry {
        telemetry
    }

    public func currentConnection() -> BikeConnection {
        connection
    }

    public func updateTelemetryIf(
        _ update: (inout BikeTelemetry) -> Bool
    ) -> BikeTelemetry? {
        var candidate = telemetry
        guard update(&candidate) else { return nil }
        telemetry = candidate
        return telemetry
    }

    public func updateConnectionIfChanged(
        _ update: (inout BikeConnection) -> Void
    ) -> BikeConnection? {
        var candidate = connection
        update(&candidate)
        guard candidate != connection else { return nil }
        connection = candidate
        return connection
    }

    public func resetSession(
        connectionState: ConnectionState
    ) -> (telemetry: BikeTelemetry, connection: BikeConnection) {
        telemetry = BikeTelemetry()
        connection = BikeConnection(state: connectionState)
        return (telemetry, connection)
    }
}
