import BikeDomain
import Foundation

struct BikeAlphaEvidencePersistence: Sendable {
    private let profileRepository: (any BikeProfileRepository)?

    init(profileRepository: (any BikeProfileRepository)?) {
        self.profileRepository = profileRepository
    }

    func persistedEvidence(matching vin: String) async -> Set<BikeAlphaEvidence> {
        guard let profileRepository,
              let profile = await profileRepository.loadProfile(),
              profile.vin == vin
        else { return [] }
        return profile.alphaEvidence
    }

    func persistNewEvidence(
        from telemetry: BikeTelemetry,
        observedAt: Date
    ) async {
        guard let profileRepository,
              case .alpha(let evidence) = telemetry.detectedPowerTier,
              !evidence.isEmpty,
              var profile = await profileRepository.loadProfile(),
              telemetry.vin.isEmpty || telemetry.vin == profile.vin
        else { return }
        let mergedEvidence = profile.alphaEvidence.union(evidence)
        guard mergedEvidence != profile.alphaEvidence else { return }
        profile.alphaEvidence = mergedEvidence
        profile.alphaDetectedAt = observedAt
        await profileRepository.saveProfile(profile)
    }
}
