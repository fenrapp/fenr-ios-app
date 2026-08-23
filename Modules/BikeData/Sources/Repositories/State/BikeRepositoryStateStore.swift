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

    public func updateTelemetry(_ update: (inout BikeTelemetry) -> Void) -> BikeTelemetry {
        update(&telemetry)
        return telemetry
    }

    public func updateConnection(_ update: (inout BikeConnection) -> Void) -> BikeConnection {
        update(&connection)
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
