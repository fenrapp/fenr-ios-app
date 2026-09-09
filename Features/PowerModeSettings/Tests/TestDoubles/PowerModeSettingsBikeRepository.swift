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
    private(set) var refreshCount = 0
    private(set) var requestedWrites: [Write] = []
    private(set) var requestedTractionWrites: [TractionWrite] = []
    private(set) var writes: [Write] = []
    private(set) var tractionWrites: [TractionWrite] = []
    var preparationError: (any Error)?
    var writeError: (any Error)?
    private let refreshOperation: ControllablePowerModeSettingsOperation?
    private let basePreparationOperation: ControllablePowerModeSettingsOperation?
    private let tractionPreparationOperation: ControllablePowerModeSettingsOperation?
    private let baseWriteOperation: ControllablePowerModeSettingsOperation?
    private let tractionWriteOperation: ControllablePowerModeSettingsOperation?
    private let tractionCompatibilityOperation: ControllablePowerModeSettingsOperation?

    init(
        refreshOperation: ControllablePowerModeSettingsOperation? = nil,
        basePreparationOperation: ControllablePowerModeSettingsOperation? = nil,
        tractionPreparationOperation: ControllablePowerModeSettingsOperation? = nil,
        baseWriteOperation: ControllablePowerModeSettingsOperation? = nil,
        tractionWriteOperation: ControllablePowerModeSettingsOperation? = nil,
        tractionCompatibilityOperation: ControllablePowerModeSettingsOperation? = nil
    ) {
        self.refreshOperation = refreshOperation
        self.basePreparationOperation = basePreparationOperation
        self.tractionPreparationOperation = tractionPreparationOperation
        self.baseWriteOperation = baseWriteOperation
        self.tractionWriteOperation = tractionWriteOperation
        self.tractionCompatibilityOperation = tractionCompatibilityOperation
    }

    func start() {}
    func stop() {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func refreshPowerModeConfigurations() async throws {
        refreshCount += 1
        try await refreshOperation?.run()
    }

    func preparePowerModeControl(mapIndex: Int) async throws {
        if let preparationError { throw preparationError }
        try await basePreparationOperation?.run()
        preparedMapIndexes.append(mapIndex)
    }

    func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        if let writeError { throw writeError }
        let write = Write(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        )
        requestedWrites.append(write)
        try await baseWriteOperation?.run()
        writes.append(write)
    }

    var tractionCompatibility = BikeTractionControlFirmwareCompatibility(firmware: "1.12.0", isCompatible: true)
    var tractionCompatibilityError: (any Error)?
    private(set) var tractionCompatibilityReads = 0

    func setTractionCompatibility(_ value: BikeTractionControlFirmwareCompatibility) { tractionCompatibility = value }
    func setTractionError(_ error: (any Error)?) { writeError = error }
    func setTractionCompatibilityError(_ error: (any Error)?) { tractionCompatibilityError = error }

    func readTractionControlFirmwareCompatibility() async throws -> BikeTractionControlFirmwareCompatibility {
        tractionCompatibilityReads += 1
        try await tractionCompatibilityOperation?.run()
        if let tractionCompatibilityError { throw tractionCompatibilityError }
        return tractionCompatibility
    }

    func applyUserTractionControlConfiguration(
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double,
        expected: BikeTractionControlSnapshot?
    ) async throws -> BikeTractionControlSnapshot {
        try await setTractionControlConfiguration(
            mapIndex: mapIndex, powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
        return .init(
            mapIndex: mapIndex, powerRaw: Int(powerTractionPercent * 10),
            brakingRaw: Int(brakingTractionPercent * 10)
        )
    }

    func prepareTractionControl(mapIndex: Int) async throws {
        if let preparationError { throw preparationError }
        try await tractionPreparationOperation?.run()
        preparedTractionMapIndexes.append(mapIndex)
    }

    func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        if let writeError { throw writeError }
        let write = TractionWrite(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
        requestedTractionWrites.append(write)
        try await tractionWriteOperation?.run()
        tractionWrites.append(write)
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
