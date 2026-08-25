import BikeDomain
import ChargeControl

@MainActor
struct ChargeControlDependencyContainer {
    func makeSession(repository: any BikeBatteryHealthRepository) -> ChargeControlSession {
        ChargeControlSession(
            useCases: ChargeControlUseCases(
                prepare: PrepareChargePowerControlUseCase(repository: repository),
                setPowerLimit: SetChargePowerLimitUseCase(repository: repository),
                setTarget: SetChargeTargetUseCase(repository: repository)
            ),
            logger: ChargeControlLogStore(),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler()
        )
    }
}
