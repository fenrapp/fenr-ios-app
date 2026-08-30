import BikeDomain
import Testing

@Suite("Bike charge power control use cases")
struct BikeChargePowerControlUseCaseTests {
    @Test("Forwards charge control values without normalization")
    func forwardsExactValues() async throws {
        let repository = RecordingBikeChargePowerControlRepository()
        let chargingStatus = BikeChargingStatus(
            requestedCurrentAmperes: -2.5,
            reportedCurrentAmperes: 1.25,
            maximumCurrentAmperes: 37.5,
            maximumPowerWatts: 7_123,
            targetCellVoltageVolts: 4.275,
            maximumStateOfChargePercent: 137,
            chargerType: .unknown(91)
        )

        let prepared = try await PrepareChargePowerControlUseCase(repository: repository)
            .execute(chargingStatus: chargingStatus)
        let power = try await SetChargePowerLimitUseCase(repository: repository).execute(watts: -500)
        let target = try await SetChargeTargetUseCase(repository: repository).execute(percent: 140)

        #expect(prepared.parsedConfig.chargePowerWatts == 7_123)
        #expect(power.parsedConfig.chargePowerWatts == -500)
        #expect(target.parsedConfig.maximumStateOfChargeDeciPercent == 1_400)
        #expect(await repository.events() == [
            .prepare(chargingStatus),
            .setPowerLimit(-500),
            .setTarget(140)
        ])
    }

    @Test("Propagates charge control repository errors")
    func propagatesErrors() async {
        let repository = RecordingBikeChargePowerControlRepository()
        await repository.setError(.expected)

        await #expect(throws: BikeChargePowerControlTestError.expected) {
            try await SetChargeTargetUseCase(repository: repository).execute(percent: 80)
        }
    }

    @Test("Default charge control implementation is unavailable")
    func defaultIsUnavailable() async {
        let repository = DefaultBikeChargePowerControlRepository()
        let status = BikeChargingStatus(
            requestedCurrentAmperes: 2,
            reportedCurrentAmperes: 2,
            maximumCurrentAmperes: 10,
            maximumPowerWatts: 3_300,
            targetCellVoltageVolts: 4.2,
            maximumStateOfChargePercent: 100
        )

        await #expect(throws: BikeChargePowerControlRepositoryError.chargePowerControlUnavailable) {
            try await PrepareChargePowerControlUseCase(repository: repository).execute(chargingStatus: status)
        }
        await #expect(throws: BikeChargePowerControlRepositoryError.chargePowerControlUnavailable) {
            try await SetChargePowerLimitUseCase(repository: repository).execute(watts: 1_000)
        }
        await #expect(throws: BikeChargePowerControlRepositoryError.chargePowerControlUnavailable) {
            try await SetChargeTargetUseCase(repository: repository).execute(percent: 80)
        }
    }
}
