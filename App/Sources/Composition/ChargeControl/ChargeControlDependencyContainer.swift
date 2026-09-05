import BikeDomain
import BLETraceDomain
import ChargeControl

@MainActor
struct ChargeControlDependencyContainer {
    func makeSession(
        repository: any BikeChargePowerControlRepository,
        captureState: BLETraceCaptureState? = nil
    ) -> ChargeControlSession {
        ChargeControlSession(
            useCases: ChargeControlUseCases(
                prepare: PrepareChargePowerControlUseCase(repository: repository),
                setPowerLimit: SetChargePowerLimitUseCase(repository: repository),
                setTarget: SetChargeTargetUseCase(repository: repository)
            ),
            logger: ChargeControlLogStore(isRecording: { captureState?.isRecording ?? false }),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler()
        )
    }
}
