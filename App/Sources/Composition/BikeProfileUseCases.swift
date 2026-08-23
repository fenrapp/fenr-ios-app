import BikeDomain

struct BikeProfileUseCases: Sendable {
    let load: LoadBikeProfileUseCase
    let clear: ClearBikeProfileUseCase
}
