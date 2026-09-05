import BikeData
import BikeDomain
import BikeSDK
import BLETraceDomain

struct BikeDataDependencyContainer {
    func makeBikePinDeriver() -> any BikePinDeriving {
        LiveBikeRepositoryFactory.makePinDeriver()
    }

    func makeBikeRepository(
        client: BikeTelemetryClient,
        profileRepository: (any BikeProfileRepository)? = nil,
        captureState: BLETraceCaptureState? = nil
    ) -> LiveBikeRepository {
        LiveBikeRepositoryFactory.makeDefault(
            client: client,
            profileRepository: profileRepository,
            diagnosticsEnabled: { captureState?.isRecording ?? false }
        )
    }
}
