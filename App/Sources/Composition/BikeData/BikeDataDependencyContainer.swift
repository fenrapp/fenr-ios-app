import BikeData
import BikeDomain
import BikeSDK

struct BikeDataDependencyContainer {
    func makeBikePinDeriver() -> any BikePinDeriving {
        LiveBikeRepositoryFactory.makePinDeriver()
    }

    func makeBikeRepository(
        client: BikeTelemetryClient,
        profileRepository: (any BikeProfileRepository)? = nil
    ) -> LiveBikeRepository {
        LiveBikeRepositoryFactory.makeDefault(client: client, profileRepository: profileRepository)
    }
}
