public struct BikeSecurityConfiguration: Equatable, Sendable {
    public let pairingDate: String

    public init(pairingDate: String) {
        self.pairingDate = pairingDate
    }
}
