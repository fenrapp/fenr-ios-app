import BikeDomain
import Observation
import VehicleSession

@MainActor
@Observable
final class PowerModeContext {
    var telemetry = BikeTelemetry()
    var connection = BikeConnection()
    var profile: BikeProfile?
    var isCanonical = false
    var selectedMap = 0
    var isStarted = false
    var isAdvancedVisible = false
    private var selectedInitialMap = false

    var isAuthenticated: Bool {
        switch connection.state {
        case .authenticated, .subscribed, .receivingTelemetry: true
        default: false
        }
    }
    var canUseConfiguration: Bool { isCanonical && isAuthenticated }
    var maximumHorsepower: Int {
        if case .alpha = telemetry.detectedPowerTier { return 80 }
        return profile?.declaredPowerTier == .alpha ? 80 : 60
    }

    func receive(_ snapshot: VehicleSessionSnapshot) {
        if profile?.vin != snapshot.profile?.vin { selectedInitialMap = false }
        telemetry = snapshot.telemetry
        connection = snapshot.connection
        profile = snapshot.profile
        isCanonical = snapshot.isCanonicalTelemetryAvailable
        if !selectedInitialMap, let index = telemetry.mode.powerModeConfigurationIndex {
            selectedMap = index
            selectedInitialMap = true
        }
    }

    func select(_ index: Int) {
        selectedMap = index
        selectedInitialMap = true
    }
}
