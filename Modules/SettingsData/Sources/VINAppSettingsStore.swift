import Foundation
import SettingsDomain
import StarkProtocol

struct VINAppSettingsStore {
    let defaults: UserDefaults
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    func load(vin: String?) throws -> AppSettings {
        let records = try loadRecords(migratingTo: vin)
        guard let vin else { return AppSettings() }
        return records[vin] ?? AppSettings().scoped(toVIN: vin)
    }

    func save(_ settings: AppSettings, vin: String) throws {
        var records = try loadRecords(migratingTo: vin)
        let scoped = settings.scoped(toVIN: vin)
        guard records[vin] != scoped else { return }
        records[vin] = scoped
        guard let data = try? encoder.encode(records) else { throw AppSettingsUpdateError.persistenceFailed }
        defaults.set(data, forKey: Constants.recordsKey)
    }

    private func loadRecords(migratingTo selectedVIN: String?) throws -> [String: AppSettings] {
        if let stored = defaults.object(forKey: Constants.recordsKey) {
            guard let data = stored as? Data,
                  let records = try? decoder.decode([String: AppSettings].self, from: data),
                  records.allSatisfy({ vin, settings in
                      StarkPairingIdentity.isValidVIN(vin) && settings.vin == vin
                  }) else { throw AppSettingsUpdateError.unreadableStore }
            return records
        }
        let legacy: AppSettings
        if let stored = defaults.object(forKey: Constants.legacyKey) {
            guard let data = stored as? Data,
                  let decoded = try? decoder.decode(AppSettings.self, from: data) else {
                throw AppSettingsUpdateError.unreadableStore
            }
            legacy = decoded
        } else {
            legacy = AppSettings()
        }
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
        guard let data = try? encoder.encode(records) else { throw AppSettingsUpdateError.persistenceFailed }
        defaults.set(data, forKey: Constants.recordsKey)
        return records
    }

    private enum Constants {
        static let legacyKey = "fenr.app.settings"
        static let recordsKey = "fenr.bike.settings.v1"
    }
}
