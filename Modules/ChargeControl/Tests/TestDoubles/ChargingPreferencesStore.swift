import BikeDomain

@MainActor
final class ChargingPreferencesStore: BikeChargingPreferencesStore {
    var values: [String: BikeChargingPreferences] = [:]
    var failsLoad = false
    var failsSave = false

    func load(vin: String) throws -> BikeChargingPreferences {
        if failsLoad { throw BikeChargingPreferencesError.unreadableStore }
        return values[vin] ?? .init()
    }

    func save(_ preferences: BikeChargingPreferences, vin: String) throws {
        if failsSave { throw BikeChargingPreferencesError.unreadableStore }
        values[vin] = preferences
    }
}
