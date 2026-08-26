import BikeDomain
import Foundation

public actor UserDefaultsBikeProfileRepository: BikeProfileRepository {
    private enum Constants {
        static let profileVINKey = "com.fenr.bikeProfile.vin"
        static let declaredPowerTierKey = "com.fenr.bikeProfile.declaredPowerTier"
        static let alphaEvidenceKey = "com.fenr.bikeProfile.alphaEvidence"
        static let alphaDetectedAtKey = "com.fenr.bikeProfile.alphaDetectedAt"
    }

    private let userDefaults: UserDefaults
    private var observers: [UUID: AsyncStream<BikeProfileState>.Continuation] = [:]

    public init() {
        userDefaults = .standard
    }

    init(suiteName: String) {
        userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public func loadProfile() -> BikeProfile? {
        guard let vin = userDefaults.string(forKey: Constants.profileVINKey) else { return nil }
        let declaredTier = userDefaults.string(forKey: Constants.declaredPowerTierKey)
            .flatMap(BikeDeclaredPowerTier.init(rawValue:)) ?? .standard
        let evidence = Set(
            userDefaults.stringArray(forKey: Constants.alphaEvidenceKey)?
                .compactMap(BikeAlphaEvidence.init(rawValue:)) ?? []
        )
        return BikeProfile(
            vin: vin,
            declaredPowerTier: declaredTier,
            alphaEvidence: evidence,
            alphaDetectedAt: userDefaults.object(forKey: Constants.alphaDetectedAtKey) as? Date
        )
    }

    public func saveProfile(_ profile: BikeProfile) {
        guard profile != loadProfile() else { return }
        userDefaults.set(profile.vin, forKey: Constants.profileVINKey)
        userDefaults.set(profile.declaredPowerTier.rawValue, forKey: Constants.declaredPowerTierKey)
        userDefaults.set(profile.alphaEvidence.map(\.rawValue).sorted(), forKey: Constants.alphaEvidenceKey)
        userDefaults.set(profile.alphaDetectedAt, forKey: Constants.alphaDetectedAtKey)
        observers.values.forEach { $0.yield(BikeProfileState(profile: profile)) }
    }

    public func clearProfile() {
        guard loadProfile() != nil else { return }
        userDefaults.removeObject(forKey: Constants.profileVINKey)
        userDefaults.removeObject(forKey: Constants.declaredPowerTierKey)
        userDefaults.removeObject(forKey: Constants.alphaEvidenceKey)
        userDefaults.removeObject(forKey: Constants.alphaDetectedAtKey)
        observers.values.forEach { $0.yield(BikeProfileState(profile: nil)) }
    }

    public func observeProfile() async -> AsyncStream<BikeProfileState> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<BikeProfileState>.makeStream()
        observers[identifier] = continuation
        continuation.yield(BikeProfileState(profile: loadProfile()))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(identifier) }
        }
        return stream
    }

    private func removeObserver(_ identifier: UUID) {
        observers.removeValue(forKey: identifier)
    }
}
