@testable import BatteryHealth
@testable import ChargeControl

@MainActor
struct BatteryChargeObservationFixture {
    let repository: FakeBatteryHealthRepository
    let model: BatteryHealthViewModel
    let control: ChargeControlSession
    let emitter: ChargeControlStateEmitter

    static func make() -> Self {
        let repository = FakeBatteryHealthRepository()
        let emitter = ChargeControlStateEmitter()
        let control = ChargeControlSession(
            useCases: .init(
                prepare: .init(repository: repository), setPowerLimit: .init(repository: repository),
                setTarget: .init(repository: repository)
            ),
            logger: ChargeControlLogStore(isRecording: { false }),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler(debounceDelay: .seconds(3_600)),
            stateEmitter: emitter,
            initialState: .init(isVisible: true, isEnabled: true, selectedWatts: 1_000, phase: .ready)
        )
        let model = makeBatteryHealthViewModel(
            repository: repository, vehicleSession: BatteryObservationVehicleSession(), chargeControl: control
        )
        return Self(repository: repository, model: model, control: control, emitter: emitter)
    }
}
