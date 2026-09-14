import BikeDomain

@MainActor
final class ChargingPreferencesMemoryStore: BikeChargingPreferencesStore {
    var values: [String: BikeChargingPreferences] = [:]
    func load(vin: String) throws -> BikeChargingPreferences { values[vin] ?? .init() }
    func save(_ preferences: BikeChargingPreferences, vin: String) throws { values[vin] = preferences }
}
