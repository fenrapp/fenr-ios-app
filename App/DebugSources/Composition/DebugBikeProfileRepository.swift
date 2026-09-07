import BikeDomain
import BikeEmulator
import Foundation

actor DebugBikeProfileRepository: BikeProfileRepository {
    private let persistence: DebugUITestProfileStore?
    private var profile: BikeProfile?
    private var observers: [UUID: AsyncStream<BikeProfileState>.Continuation] = [:]

    init(initialProfile: BikeProfile? = nil, persistence: DebugUITestProfileStore? = nil) {
        self.persistence = persistence
        profile = initialProfile
    }

    func loadProfile() async -> BikeProfile? {
        profile
    }

    func saveProfile(_ profile: BikeProfile) async {
        guard profile != self.profile else { return }
        self.profile = profile
        persistence?.save(profile)
        observers.values.forEach { $0.yield(BikeProfileState(profile: profile)) }
    }

    func clearProfile() async {
        guard profile != nil else { return }
        profile = nil
        persistence?.save(nil)
        observers.values.forEach { $0.yield(BikeProfileState(profile: nil)) }
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
        persistence?.save(profile)
        observers.values.forEach { $0.yield(BikeProfileState(profile: profile)) }
    }

    func observeProfile() async -> AsyncStream<BikeProfileState> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<BikeProfileState>.makeStream()
        observers[identifier] = continuation
        continuation.yield(BikeProfileState(profile: profile))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(identifier) }
        }
        return stream
    }

    private func removeObserver(_ identifier: UUID) {
        observers.removeValue(forKey: identifier)
    }
}
