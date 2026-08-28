import BikeDomain

actor PowerModeSettingsBikeRepository: BikeRepository {
    struct Write: Equatable, Sendable {
        let mapIndex: Int
        let horsepower: Int
        let regenerativeBrakingPercent: Int
    }

    struct TractionWrite: Equatable, Sendable {
        let mapIndex: Int
        let powerTractionPercent: Double
        let brakingTractionPercent: Double
    }

    private(set) var preparedMapIndexes: [Int] = []
    private(set) var preparedTractionMapIndexes: [Int] = []
    private(set) var writes: [Write] = []
    private(set) var tractionWrites: [TractionWrite] = []
    var preparationError: (any Error)?
    var writeError: (any Error)?

    func start() {}
    func stop() {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func preparePowerModeControl(mapIndex: Int) async throws {
        if let preparationError { throw preparationError }
        preparedMapIndexes.append(mapIndex)
    }

    func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        if let writeError { throw writeError }
        writes.append(.init(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        ))
    }

    func prepareTractionControl(mapIndex: Int) async throws {
        if let preparationError { throw preparationError }
        preparedTractionMapIndexes.append(mapIndex)
    }

    func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        if let writeError { throw writeError }
        tractionWrites.append(.init(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        ))
    }

    func observeTelemetry() -> AsyncStream<BikeTelemetry> {
        AsyncStream { $0.finish() }
    }

    func observeConnection() -> AsyncStream<BikeConnection> {
        AsyncStream { $0.finish() }
    }

    func observeDebugEvents() -> AsyncStream<BikeDebugEvent> {
        AsyncStream { $0.finish() }
    }
}
