import BikeDomain
import ChargeControl

@MainActor
struct ChargingPreferencesFixture {
    let repository: ChargingPreferencesRepository
    let store: ChargingPreferencesStore
    let controller: ChargingPreferencesController

    static func make() -> Self {
        let repository = ChargingPreferencesRepository()
        let store = ChargingPreferencesStore()
        return .init(repository: repository, store: store, controller: .init(
            useCases: .init(repository: repository), store: store, emitter: ChargingPreferencesEmitter()
        ))
    }

    func connect(_ ready: Bool, vin: String = "FENRTEST000000001", charger: BikeChargerType? = nil) {
        controller.receive(.init(vin: vin, isReady: ready, isChargerConnected: charger != nil, charger: charger))
    }
}
