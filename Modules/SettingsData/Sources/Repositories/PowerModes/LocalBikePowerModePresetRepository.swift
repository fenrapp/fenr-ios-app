import BikeDomain
import Foundation
import StarkProtocol

public actor LocalBikePowerModePresetRepository: BikePowerModePresetRepository {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(defaults: UserDefaults, encoder: JSONEncoder, decoder: JSONDecoder) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    public func load(vin: String) throws -> [BikePowerModePreset] {
        let key = try storageKey(vin)
        guard let object = defaults.object(forKey: key) else { return [] }
        guard let data = object as? Data,
              let values = try? decoder.decode([BikePowerModePreset].self, from: data),
              Set(values.map(\.id)).count == values.count, values.allSatisfy(isValid) else {
            throw BikePowerCurveError.unreadableStore
        }
        return values
    }

    public func save(_ presets: [BikePowerModePreset], vin: String) throws {
        guard Set(presets.map(\.id)).count == presets.count,
              presets.allSatisfy(isValid) else {
            throw BikePowerCurveError.invalidValues
        }
        let key = try storageKey(vin)
        let data = try encoder.encode(presets)
        defaults.set(data, forKey: key)
    }

    private func isValid(_ preset: BikePowerModePreset) -> Bool {
        let value = preset.configuration
        return !preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.power.count == 15 && value.regeneration.count == 15
            && value.power.allSatisfy { 0 ... 1_000 ~= $0 }
            && value.regeneration.allSatisfy { 0 ... 1_000 ~= $0 }
            && 0 ... 4 ~= value.mapIndex && value.curve == value.mapIndex + 1
            && [60, 80].contains(preset.maximumHorsepower)
    }

    private func storageKey(_ vin: String) throws -> String {
        guard StarkPairingIdentity.isValidVIN(vin) else { throw BikePowerCurveError.invalidValues }
        return "fenr.power-mode-presets.v1." + StarkPairingIdentity.normalizedVIN(vin)
    }
}
