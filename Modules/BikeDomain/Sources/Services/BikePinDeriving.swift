public protocol BikePinDeriving: Sendable {
    func derivePin(vin: String) -> String
}
