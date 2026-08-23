public struct BikeProfile: Equatable, Sendable {
    public let vin: String

    public init(vin: String) {
        self.vin = vin
    }
}
