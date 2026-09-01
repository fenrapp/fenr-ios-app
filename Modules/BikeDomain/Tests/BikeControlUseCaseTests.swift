import BikeDomain
import Testing

@Suite("Bike control use cases")
struct BikeControlUseCaseTests {
    @Test("Forwards every control value without normalization")
    func forwardsExactValues() async throws {
        let repository = RecordingBikeControlRepository()

        let preparedLock = try await PrepareBikeLockControlUseCase(repository: repository).execute()
        let locked = try await SetBikeLockedUseCase(repository: repository).execute(true)
        try await RefreshBikePowerModesUseCase(repository: repository).execute()
        try await RefreshBikePowerModeConfigurationUseCase(repository: repository).execute(mapIndex: -3)
        try await PrepareBikePowerModeControlUseCase(repository: repository).execute(mapIndex: 6)
        try await SetBikePowerModeConfigurationUseCase(repository: repository).execute(
            mapIndex: -1,
            horsepower: -12,
            regenerativeBrakingPercent: 137
        )
        try await PrepareBikeTractionControlUseCase(repository: repository).execute(mapIndex: 99)
        try await SetBikeTractionControlConfigurationUseCase(repository: repository).execute(
            mapIndex: -5,
            powerTractionPercent: -12.5,
            brakingTractionPercent: 145.75
        )
        try await RefreshBikeTractionControlConfigurationUseCase(repository: repository).execute(mapIndex: 6)

        #expect(preparedLock.isLocked == false)
        #expect(locked.isLocked)
        #expect(await repository.events() == [
            .prepareBikeLock,
            .setBikeLocked(true),
            .refreshPowerModes,
            .refreshPowerMode(mapIndex: -3),
            .preparePowerMode(mapIndex: 6),
            .setPowerMode(mapIndex: -1, horsepower: -12, regenerativeBrakingPercent: 137),
            .prepareTraction(mapIndex: 99),
            .setTraction(mapIndex: -5, powerPercent: -12.5, brakingPercent: 145.75),
            .refreshTraction(mapIndex: 6)
        ])
    }

    @Test("Propagates repository errors")
    func propagatesErrors() async {
        let repository = RecordingBikeControlRepository()
        await repository.setError(.expected)

        await #expect(throws: BikeControlTestError.expected) {
            try await SetBikePowerModeConfigurationUseCase(repository: repository).execute(
                mapIndex: 2,
                horsepower: 80,
                regenerativeBrakingPercent: -20
            )
        }
    }

    @Test("Default control implementation fails closed and keeps refresh defaults")
    func defaultsFailClosed() async throws {
        let repository = DefaultBikeControlRepository()

        await #expect(throws: BikeControlRepositoryError.bikeLockControlUnavailable) {
            try await PrepareBikeLockControlUseCase(repository: repository).execute()
        }
        await #expect(throws: BikeControlRepositoryError.powerModeControlUnavailable) {
            try await PrepareBikePowerModeControlUseCase(repository: repository).execute(mapIndex: 0)
        }
        await #expect(throws: BikeControlRepositoryError.tractionControlUnavailable) {
            try await PrepareBikeTractionControlUseCase(repository: repository).execute(mapIndex: 0)
        }
        try await RefreshBikePowerModesUseCase(repository: repository).execute()
        try await RefreshBikePowerModeConfigurationUseCase(repository: repository).execute(mapIndex: 0)
        try await RefreshBikeTractionControlConfigurationUseCase(repository: repository).execute(mapIndex: 0)

        #expect(
            BikeControlRepositoryError.bikeLockControlUnavailable.errorDescription
                == "Bike Lock control is unavailable"
        )
        #expect(
            BikeControlRepositoryError.powerModeControlUnavailable.errorDescription
                == "Power mode control is unavailable"
        )
        #expect(
            BikeControlRepositoryError.tractionControlUnavailable.errorDescription
                == "Traction control is unavailable"
        )
    }
}
