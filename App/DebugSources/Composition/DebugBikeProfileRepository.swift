import BikeDomain
import BikeEmulator
import Foundation

actor DebugBikeProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?
    private var observers: [UUID: AsyncStream<BikeProfile?>.Continuation] = [:]

    init(initialProfile: BikeProfile? = nil) {
        profile = initialProfile
    }

    func loadProfile() async -> BikeProfile? {
        profile
    }

    func saveProfile(_ profile: BikeProfile) async {
        self.profile = profile
        observers.values.forEach { $0.yield(profile) }
    }

    func clearProfile() async {
        profile = nil
        observers.values.forEach { $0.yield(nil) }
    }

    func apply(preset: BikeEmulatorPowerModePreset) {
        guard var profile else { return }
        profile.declaredPowerTier = preset.declaredTier
        switch preset {
        case .alpha, .mismatch:
            profile.alphaEvidence = [.powerAboveStandard, .tractionControlConfigured]
            profile.alphaDetectedAt = Date()
        case .standard, .claimedAlpha, .partial, .failure:
            profile.alphaEvidence = []
            profile.alphaDetectedAt = nil
        }
        self.profile = profile
        observers.values.forEach { $0.yield(profile) }
    }

    func observeProfile() -> AsyncStream<BikeProfile?> {
        let identifier = UUID()
        return AsyncStream { continuation in
            observers[identifier] = continuation
            continuation.yield(profile)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(identifier) }
            }
        }
    }

    private func removeObserver(_ identifier: UUID) {
        observers.removeValue(forKey: identifier)
    }
}
