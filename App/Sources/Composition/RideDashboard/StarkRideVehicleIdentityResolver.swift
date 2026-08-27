import RideSession
import StarkProtocol

struct StarkRideVehicleIdentityResolver: RideVehicleIdentityResolving {
    func confirmedVIN(from candidate: String) -> String? {
        let normalized = StarkPairingIdentity.normalizedVIN(candidate)
        return StarkPairingIdentity.isValidVIN(normalized) ? normalized : nil
    }
}
