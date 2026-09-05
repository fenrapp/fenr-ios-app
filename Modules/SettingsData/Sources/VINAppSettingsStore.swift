import Foundation
import SettingsDomain
import StarkProtocol

struct VINAppSettingsStore {
    let defaults: UserDefaults
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    func load(vin: String?) -> AppSettings {
        let records = loadRecords(migratingTo: vin)
        guard let vin else { return AppSettings() }
        return records?[vin] ?? AppSettings().scoped(toVIN: vin)
    }

    func save(_ settings: AppSettings, vin: String) -> Bool {
        guard var records = loadRecords(migratingTo: vin) else { return false }
        let scoped = settings.scoped(toVIN: vin)
        guard records[vin] != scoped else { return false }
        records[vin] = scoped
        guard let data = try? encoder.encode(records) else { return false }
        defaults.set(data, forKey: Constants.recordsKey)
        return true
    }

    private func loadRecords(migratingTo selectedVIN: String?) -> [String: AppSettings]? {
        if let data = defaults.data(forKey: Constants.recordsKey) {
            guard let records = try? decoder.decode([String: AppSettings].self, from: data),
                  records.allSatisfy({ vin, settings in
                      StarkPairingIdentity.isValidVIN(vin) && settings.vin == vin
                  }) else { return nil }
            return records
        }
        let legacy = defaults.data(forKey: Constants.legacyKey)
            .flatMap { try? decoder.decode(AppSettings.self, from: $0) } ?? AppSettings()
        let knownVINs = Set(legacy.batteryPackCapacitiesByVIN.keys)
            .union(legacy.powerModeNamesByVIN.keys)
            .union(legacy.bikeLockSettingsByVIN.keys)
        var records: [String: AppSettings] = [:]
        for vin in knownVINs where StarkPairingIdentity.isValidVIN(vin) {
            let bikeSettings = AppSettings(
                batteryPackCapacitiesByVIN: legacy.batteryPackCapacitiesByVIN,
                powerModeNamesByVIN: legacy.powerModeNamesByVIN,
                bikeLockSettingsByVIN: legacy.bikeLockSettingsByVIN
            )
            records[vin] = bikeSettings.scoped(toVIN: vin)
        }
        if let selectedVIN {
            records[selectedVIN] = legacy.scoped(toVIN: selectedVIN)
        }
        guard let data = try? encoder.encode(records) else { return nil }
        defaults.set(data, forKey: Constants.recordsKey)
        return records
    }

    private enum Constants {
        static let legacyKey = "fenr.app.settings"
        static let recordsKey = "fenr.bike.settings.v1"
    }
}
