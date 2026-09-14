@MainActor
public protocol BikeChargingPreferencesStore {
    func load(vin: String) throws -> BikeChargingPreferences
    func save(_ preferences: BikeChargingPreferences, vin: String) throws
}

public enum BikeChargingPreferencesError: Error {
    case unreadableStore
    case invalidValues
}
