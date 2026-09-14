import BikeDomain
import ChargeControl

@MainActor
public struct ChargingSettingsUseCases {
    private let controller: ChargingPreferencesController

    public init(controller: ChargingPreferencesController) { self.controller = controller }

    var state: ChargingPreferencesState { controller.state }
    func observe() -> AsyncStream<ChargingPreferencesState> { controller.observe() }
    func setPower(_ watts: Double) { controller.setPower(watts: watts) }
    func setTarget(_ percent: Double) { controller.setTarget(percent: percent) }
    func selectCharger(_ charger: BikeChargerType) { controller.selectCharger(charger) }
    func cancel() { controller.cancelPending() }
    func retry() { controller.retry() }
}
