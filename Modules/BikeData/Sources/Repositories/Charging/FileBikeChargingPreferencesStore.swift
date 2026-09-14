import BikeDomain
import Foundation
import StarkProtocol

@MainActor
public struct FileBikeChargingPreferencesStore: BikeChargingPreferencesStore {
    private let url: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL, fileManager: FileManager, encoder: JSONEncoder, decoder: JSONDecoder) {
        self.url = url
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    public func load(vin: String) throws -> BikeChargingPreferences {
        guard StarkPairingIdentity.isValidVIN(vin) else { throw BikeChargingPreferencesError.invalidValues }
        return try records()[vin] ?? .init()
    }

    public func save(_ preferences: BikeChargingPreferences, vin: String) throws {
        guard StarkPairingIdentity.isValidVIN(vin), Self.isValid(preferences) else {
            throw BikeChargingPreferencesError.invalidValues
        }
        var records = try records()
        records[vin] = preferences
        let data = try encoder.encode(records)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func records() throws -> [String: BikeChargingPreferences] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        do {
            let values = try decoder.decode([String: BikeChargingPreferences].self, from: Data(contentsOf: url))
            guard values.allSatisfy({ StarkPairingIdentity.isValidVIN($0.key) && Self.isValid($0.value) }) else {
                throw BikeChargingPreferencesError.unreadableStore
            }
            return values
        } catch {
            throw BikeChargingPreferencesError.unreadableStore
        }
    }

    private static func isValid(_ value: BikeChargingPreferences) -> Bool {
        if case .unknown = value.selectedCharger { return false }
        if let target = value.pendingTarget, !(1 ... 100).contains(target.percent) { return false }
        if let power = value.pendingPower {
            if case .unknown = power.charger { return false }
            guard (300 ... power.charger.maximumChargePowerWatts).contains(power.watts),
                  power.watts.isMultiple(of: 100) else { return false }
        }
        return true
    }
}
