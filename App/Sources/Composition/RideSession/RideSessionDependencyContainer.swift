import BikeDomain
import Foundation
import RideSession
import RideSessionDomain
import VehicleSession

enum RideSessionDependencyContainer {
    static func makeService(
        dependencies: RideSessionDependencies,
        vehicleSession: any VehicleSessionService
    ) -> any RideSessionService {
        LiveRideSessionService(
            useCases: RideSessionUseCases(
                prepare: .init(repository: dependencies.rideTripRepository)
            ),
            vehicleSession: vehicleSession,
            persistence: RideSessionPersistenceCoordinator(repository: dependencies.rideTripRepository),
            identityResolver: StarkRideVehicleIdentityResolver(),
            initialContext: BikeSessionContext(
                applicationSessionID: dependencies.applicationSessionID,
                vehicleIdentity: .temporary(UUID())
            ),
            now: Date.init
        )
    }
}

struct RideSessionDependencies {
    let rideTripRepository: any RideTripRepository
    let applicationSessionID: UUID
}
