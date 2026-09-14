import BikeData
import BikeDomain
import BLETraceDomain
import ChargeControl
import Foundation

@MainActor
struct ChargeControlDependencyContainer {
    func makeSession(
        repository: any BikeChargePowerControlRepository,
        captureState: BLETraceCaptureState? = nil,
        storageNamespace: String = "live"
    ) -> ChargeControlSession {
        ChargeControlSession(
            useCases: ChargeControlUseCases(
                prepare: PrepareChargePowerControlUseCase(repository: repository),
                setPowerLimit: SetChargePowerLimitUseCase(repository: repository),
                setTarget: SetChargeTargetUseCase(repository: repository)
            ),
            logger: ChargeControlLogStore(isRecording: { captureState?.isRecording ?? false }),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler(),
            stateEmitter: ChargeControlStateEmitter(),
            preferencesController: ChargingPreferencesController(
                useCases: ChargingPreferencesUseCases(repository: repository),
                store: FileBikeChargingPreferencesStore(
                    url: URL.applicationSupportDirectory
                        .appendingPathComponent("ChargingPreferences/\(storageNamespace).json"),
                    fileManager: .default, encoder: JSONEncoder(), decoder: JSONDecoder()
                ),
                emitter: ChargingPreferencesEmitter()
            )
        )
    }
}
