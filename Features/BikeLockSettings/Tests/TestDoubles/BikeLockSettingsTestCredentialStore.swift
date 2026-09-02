import SettingsDomain

actor BikeLockSettingsTestCredentialStore: BikeLockCredentialStoring {
    struct Failure: Error {}

    private var pins: [String: String]
    private var shouldFailWrites = false

    init(vin: String, pin: String? = nil) {
        pins = pin.map { [vin: $0] } ?? [:]
    }

    func save(pin: String, for vehicleIdentifier: String) throws {
        if shouldFailWrites { throw Failure() }
        pins[vehicleIdentifier] = pin
    }
    func verify(pin: String, for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] == pin }
    func containsPIN(for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] != nil }
    func removePIN(for vehicleIdentifier: String) throws {
        if shouldFailWrites { throw Failure() }
        pins[vehicleIdentifier] = nil
    }
    func storedPIN(for vehicleIdentifier: String) -> String? { pins[vehicleIdentifier] }
    func failWrites() { shouldFailWrites = true }
}
