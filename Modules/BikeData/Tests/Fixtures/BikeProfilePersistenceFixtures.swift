import BikeDomain
import Foundation

enum BikeProfilePersistenceFixtures {
    static let profileVINKey = "com.fenr.bikeProfile.vin"
    static let declaredPowerTierKey = "com.fenr.bikeProfile.declaredPowerTier"
    static let alphaEvidenceKey = "com.fenr.bikeProfile.alphaEvidence"
    static let alphaDetectedAtKey = "com.fenr.bikeProfile.alphaDetectedAt"

    static let vin = "FENRTEST000000001"
    static let detectedAt = Date(timeIntervalSince1970: 1_700_000_000)
    static let profile = BikeProfile(
        vin: vin,
        declaredPowerTier: .alpha,
        alphaEvidence: [.powerAboveStandard, .tractionControlConfigured],
        alphaDetectedAt: detectedAt
    )
}
