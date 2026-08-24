import BikeData
import BikeDomain
import BikeSDK

struct BikeDataDependencyContainer {
    func makeBikePinDeriver() -> any BikePinDeriving {
        LiveBikeRepositoryFactory.makePinDeriver()
    }

    func makeBikeRepository(client: BikeTelemetryClient) -> LiveBikeRepository {
        LiveBikeRepositoryFactory.makeDefault(client: client)
    }
}
