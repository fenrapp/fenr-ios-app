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
    private var observers: [UUID: AsyncStream<BikeProfile?>.Continuation] = [:]

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
        userDefaults.set(profile.vin, forKey: Constants.profileVINKey)
        userDefaults.set(profile.declaredPowerTier.rawValue, forKey: Constants.declaredPowerTierKey)
        userDefaults.set(profile.alphaEvidence.map(\.rawValue).sorted(), forKey: Constants.alphaEvidenceKey)
        userDefaults.set(profile.alphaDetectedAt, forKey: Constants.alphaDetectedAtKey)
        observers.values.forEach { $0.yield(profile) }
    }

    public func clearProfile() {
        userDefaults.removeObject(forKey: Constants.profileVINKey)
        userDefaults.removeObject(forKey: Constants.declaredPowerTierKey)
        userDefaults.removeObject(forKey: Constants.alphaEvidenceKey)
        userDefaults.removeObject(forKey: Constants.alphaDetectedAtKey)
        observers.values.forEach { $0.yield(nil) }
    }

    public func observeProfile() -> AsyncStream<BikeProfile?> {
        let identifier = UUID()
        return AsyncStream { continuation in
            observers[identifier] = continuation
            continuation.yield(loadProfile())
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(identifier) }
            }
        }
    }

    private func removeObserver(_ identifier: UUID) {
        observers.removeValue(forKey: identifier)
    }
}
