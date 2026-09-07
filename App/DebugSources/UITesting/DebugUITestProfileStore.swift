import BikeDomain
import Foundation

final class DebugUITestProfileStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock: NSLock

    init(defaults: UserDefaults, encoder: JSONEncoder, decoder: JSONDecoder, lock: NSLock) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
        self.lock = lock
    }

    func load() -> BikeProfile? {
        lock.withLock {
            defaults.data(forKey: Constants.key).flatMap { try? decoder.decode(Record.self, from: $0) }?.profile
        }
    }

    func save(_ profile: BikeProfile?) {
        lock.withLock {
            guard let profile else {
                defaults.removeObject(forKey: Constants.key)
                return
            }
            guard let data = try? encoder.encode(Record(profile: profile)) else { return }
            defaults.set(data, forKey: Constants.key)
        }
    }

    private struct Record: Codable {
        let vin: String
        let declaredTier: String
        let alphaEvidence: [String]
        let alphaDetectedAt: Date?

        init(profile: BikeProfile) {
            vin = profile.vin
            declaredTier = profile.declaredPowerTier.rawValue
            alphaEvidence = profile.alphaEvidence.map(\.rawValue).sorted()
            alphaDetectedAt = profile.alphaDetectedAt
        }

        var profile: BikeProfile {
            .init(
                vin: vin,
                declaredPowerTier: BikeDeclaredPowerTier(rawValue: declaredTier) ?? .standard,
                alphaEvidence: Set(alphaEvidence.compactMap(BikeAlphaEvidence.init(rawValue:))),
                alphaDetectedAt: alphaDetectedAt
            )
        }
    }

    private enum Constants {
        static let key = "uiTesting.bikeProfile"
    }
}
