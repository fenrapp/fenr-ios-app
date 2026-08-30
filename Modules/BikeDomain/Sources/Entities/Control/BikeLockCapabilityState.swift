public struct BikeLockCapabilityState: Equatable, Sendable {
    public let vehicleIdentifier: String?
    public let isAvailable: Bool

    public init(
        vehicleIdentifier: String? = nil,
        isAvailable: Bool = false
    ) {
        self.vehicleIdentifier = vehicleIdentifier
        self.isAvailable = isAvailable
    }
}
