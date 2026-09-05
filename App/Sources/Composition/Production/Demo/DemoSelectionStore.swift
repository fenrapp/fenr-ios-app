import Foundation
import StarkProtocol

@MainActor
struct DemoSelectionStore {
    let defaults: UserDefaults
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let makeID: () -> UUID
    let makeDigits: () -> String
    let now: () -> Date

    func load() throws -> DemoIdentity? {
        try decode(defaults.data(forKey: Constants.selectionKey))
    }

    func loadSavedIdentity() throws -> DemoIdentity? {
        try decode(defaults.data(forKey: Constants.savedIdentityKey) ?? defaults.data(forKey: Constants.selectionKey))
    }

    private func decode(_ data: Data?) throws -> DemoIdentity? {
        guard let data else { return nil }
        let identity = try decoder.decode(DemoIdentity.self, from: data)
        guard StarkPairingIdentity.isValidVIN(identity.vin), identity.vin.hasPrefix("FENRTEST") else {
            throw DemoPreparationError.invalidIdentity
        }
        return identity
    }

    func makeIdentity() throws -> DemoIdentity {
        let vin = "FENRTEST" + makeDigits()
        guard StarkPairingIdentity.isValidVIN(vin) else { throw DemoPreparationError.invalidIdentity }
        return DemoIdentity(id: makeID(), vin: vin, createdAt: now())
    }

    func save(_ identity: DemoIdentity) throws {
        let data = try encoder.encode(identity)
        defaults.set(data, forKey: Constants.savedIdentityKey)
        defaults.set(data, forKey: Constants.selectionKey)
    }

    func deactivate() throws {
        if let identity = try? load() {
            defaults.set(try encoder.encode(identity), forKey: Constants.savedIdentityKey)
        } else if defaults.data(forKey: Constants.savedIdentityKey) == nil,
                  let data = defaults.data(forKey: Constants.selectionKey) {
            // Preserve unreadable identity data while allowing recovery to real onboarding.
            defaults.set(data, forKey: Constants.savedIdentityKey)
        }
        defaults.removeObject(forKey: Constants.selectionKey)
    }

    private enum Constants {
        static let savedIdentityKey = "com.fenr.experience.saved-demo.v1"
        static let selectionKey = "com.fenr.experience.demo.v1"
    }
}

enum DemoPreparationError: Error {
    case invalidIdentity
    case invalidState
    case unavailableStorage
    case seedingFailed
}
