public protocol RideVehicleIdentityResolving: Sendable {
    func confirmedVIN(from candidate: String) -> String?
}
