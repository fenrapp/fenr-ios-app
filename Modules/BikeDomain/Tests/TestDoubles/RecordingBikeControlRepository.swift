import BikeDomain

enum BikeControlEvent: Equatable, Sendable {
    case prepareBikeLock
    case setBikeLocked(Bool)
    case refreshPowerModes
    case refreshPowerMode(mapIndex: Int)
    case preparePowerMode(mapIndex: Int)
    case setPowerMode(mapIndex: Int, horsepower: Int, regenerativeBrakingPercent: Int)
    case prepareTraction(mapIndex: Int)
    case setTraction(mapIndex: Int, powerPercent: Double, brakingPercent: Double)
    case refreshTraction(mapIndex: Int)
}

actor RecordingBikeControlRepository: BikeControlRepository {
    private var recordedEvents: [BikeControlEvent] = []
    private var currentError: BikeControlTestError?

    func prepareBikeLockControl() async throws -> BikeLockControlSnapshot {
        try record(.prepareBikeLock)
        return lockSnapshot(isLocked: false)
    }

    func setBikeLocked(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        try record(.setBikeLocked(isLocked))
        return lockSnapshot(isLocked: isLocked)
    }

    func refreshPowerModeConfigurations() async throws {
        try record(.refreshPowerModes)
    }

    func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try record(.refreshPowerMode(mapIndex: mapIndex))
    }

    func preparePowerModeControl(mapIndex: Int) async throws {
        try record(.preparePowerMode(mapIndex: mapIndex))
    }

    func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try record(.setPowerMode(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        ))
    }

    func prepareTractionControl(mapIndex: Int) async throws {
        try record(.prepareTraction(mapIndex: mapIndex))
    }

    func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try record(.setTraction(
            mapIndex: mapIndex,
            powerPercent: powerTractionPercent,
            brakingPercent: brakingTractionPercent
        ))
    }

    func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try record(.refreshTraction(mapIndex: mapIndex))
    }

    func events() -> [BikeControlEvent] {
        recordedEvents
    }

    func setError(_ error: BikeControlTestError) {
        currentError = error
    }

    private func record(_ event: BikeControlEvent) throws {
        if let currentError { throw currentError }
        recordedEvents.append(event)
    }

    private func lockSnapshot(isLocked: Bool) -> BikeLockControlSnapshot {
        .init(vcuFirmware: "1.12.0", isLocked: isLocked, didPassNoOpWrite: true)
    }
}

struct DefaultBikeControlRepository: BikeControlRepository {}

enum BikeControlTestError: Error, Equatable {
    case expected
}
