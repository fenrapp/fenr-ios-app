@testable import ChargeControl
import Foundation
@testable import RideDashboard
import SettingsDomain

@MainActor
struct ChargingObservationFixture {
    let repository: ChargingDashboardRepository
    let model: ChargingDashboardViewModel
    let control: ChargeControlSession
    let emitter: ChargeControlStateEmitter

    static func make() -> Self {
        let repository = ChargingDashboardRepository()
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
        let makeMapper: @Sendable (AppSettings, String?) -> ChargingDashboardMapper = { settings, vin in
            RideDashboardMapperFactory.makeChargingMapper(
                settings: settings, locale: Locale(identifier: "en_US"), vin: vin
            )
        }
        let model = ChargingDashboardViewModel(
            vehicleSession: ChargingDashboardVehicleSession(), chargeControl: control,
            mapper: makeMapper(.init(), nil), makeMapper: makeMapper
        )
        return Self(repository: repository, model: model, control: control, emitter: emitter)
    }
}
