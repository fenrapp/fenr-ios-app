import Foundation

public struct BikeProfile: Equatable, Sendable {
    public let vin: String
    public var declaredPowerTier: BikeDeclaredPowerTier
    public var alphaEvidence: Set<BikeAlphaEvidence>
    public var alphaDetectedAt: Date?

    public init(
        vin: String,
        declaredPowerTier: BikeDeclaredPowerTier = .standard,
        alphaEvidence: Set<BikeAlphaEvidence> = [],
        alphaDetectedAt: Date? = nil
    ) {
        self.vin = vin
        self.declaredPowerTier = declaredPowerTier
        self.alphaEvidence = alphaEvidence
        self.alphaDetectedAt = alphaDetectedAt
    }
}
