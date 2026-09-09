import BikeDomain

public actor BikeRepositoryStateStore {
    private var telemetry = BikeTelemetry()
    private var connection = BikeConnection()
    private var generation: UInt64 = 0
    private var curveRevision: UInt64 = 0
    private var confirmedCurveRevisions: [Int: UInt64] = [:]

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
        generation &+= 1
        confirmedCurveRevisions.removeAll()
        telemetry = BikeTelemetry()
        connection = BikeConnection(state: connectionState)
        return (telemetry, connection)
    }

    func curveReadContext(mapIndex: Int) -> PowerModeCurveReadContext {
        curveRevision &+= 1
        return .init(
            generation: generation, revision: curveRevision, mapIndex: mapIndex,
            confirmation: telemetry.powerModeConfigurations[mapIndex]?.curveConfirmation ?? .init()
        )
    }

    func confirmCurves(
        _ value: BikeAdvancedPowerModeConfiguration?, context: PowerModeCurveReadContext,
        advancedEditBaseline: BikeAdvancedPowerModeConfiguration? = nil
    ) -> BikeTelemetry? {
        guard context.generation == generation,
              context.revision > (confirmedCurveRevisions[context.mapIndex] ?? 0) else { return nil }
        var configuration = telemetry.powerModeConfigurations[context.mapIndex]
            ?? .init(mapIndex: context.mapIndex)
        if let value {
            guard value.mapIndex == context.mapIndex else { return nil }
            configuration.curveConfirmation = configuration.curveConfirmation.confirming(value).merging(
                context.confirmation.confirming(value, advancedEditBaseline: advancedEditBaseline)
            )
        } else {
            configuration.curveConfirmation = .init()
        }
        confirmedCurveRevisions[context.mapIndex] = context.revision
        guard configuration != telemetry.powerModeConfigurations[context.mapIndex] else { return nil }
        telemetry.powerModeConfigurations[context.mapIndex] = configuration
        return telemetry
    }
}
