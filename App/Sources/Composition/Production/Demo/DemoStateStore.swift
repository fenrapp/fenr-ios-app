import BikeEmulator
import Foundation
import StarkProtocol

final class DemoStateStore: @unchecked Sendable {
    private let vin: String
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock: NSLock
    private var isEnabled = true

    init(vin: String, defaults: UserDefaults, encoder: JSONEncoder, decoder: JSONDecoder, lock: NSLock) {
        self.vin = vin
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
        self.lock = lock
    }

    func load() throws -> BikeEmulatorState {
        try lock.withLock {
            guard StarkPairingIdentity.isValidVIN(vin) else { throw DemoPreparationError.invalidIdentity }
            if let data = defaults.data(forKey: Constants.stateKey) {
                let record = try decoder.decode(Record.self, from: data)
                guard record.vin == vin, record.state.isValid else { throw DemoPreparationError.invalidState }
                return record.state
            }
            guard let legacy = defaults.data(forKey: Constants.legacyStateKey) else { return BikeEmulatorState() }
            let state = try decoder.decode(BikeEmulatorState.self, from: legacy)
            guard state.isValid else { throw DemoPreparationError.invalidState }
            defaults.set(try encoder.encode(Record(vin: vin, state: state)), forKey: Constants.stateKey)
            return state
        }
    }

    func save(_ state: BikeEmulatorState) {
        lock.withLock {
            if let existing = defaults.data(forKey: Constants.stateKey) {
                guard let record = try? decoder.decode(Record.self, from: existing), record.vin == vin else { return }
            }
            guard isEnabled, StarkPairingIdentity.isValidVIN(vin), state.isValid,
                  let data = try? encoder.encode(Record(vin: vin, state: state)) else { return }
            defaults.set(data, forKey: Constants.stateKey)
        }
    }

    func invalidate() {
        lock.withLock { isEnabled = false }
    }

    private struct Record: Codable {
        let vin: String
        let state: BikeEmulatorState
    }

    private enum Constants {
        static let stateKey = "emulator.state.v2"
        static let legacyStateKey = "emulator.state.v1"
    }
}
