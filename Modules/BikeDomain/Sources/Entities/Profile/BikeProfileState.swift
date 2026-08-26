public struct BikeProfileState: Equatable, Sendable {
    public let profile: BikeProfile?

    public init(profile: BikeProfile?) {
        self.profile = profile
    }
}
