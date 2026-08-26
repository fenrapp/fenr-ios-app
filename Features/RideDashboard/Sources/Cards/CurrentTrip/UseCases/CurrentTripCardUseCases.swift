import BikeDomain
import EnvironmentDomain
import RideSessionDomain
import SettingsDomain

public struct CurrentTripCardUseCases: Sendable {
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let prepareRideTripSession: PrepareRideTripSessionUseCase
    let saveActiveRideTrip: SaveActiveRideTripUseCase
    let completeRideTrip: CompleteRideTripUseCase

    public init(
        observeTelemetry: ObserveBikeTelemetryUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        prepareRideTripSession: PrepareRideTripSessionUseCase,
        saveActiveRideTrip: SaveActiveRideTripUseCase,
        completeRideTrip: CompleteRideTripUseCase
    ) {
        self.observeTelemetry = observeTelemetry
        self.observeConnection = observeConnection
        self.observeSettings = observeSettings
        self.observeDeviceSpeed = observeDeviceSpeed
        self.prepareRideTripSession = prepareRideTripSession
        self.saveActiveRideTrip = saveActiveRideTrip
        self.completeRideTrip = completeRideTrip
    }
}
