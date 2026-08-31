import SettingsDomain

actor BikeLockSettingsTestCredentialStore: BikeLockCredentialStoring {
    private var pins: [String: String]

    init(vin: String, pin: String? = nil) {
        pins = pin.map { [vin: $0] } ?? [:]
    }

    func save(pin: String, for vehicleIdentifier: String) { pins[vehicleIdentifier] = pin }
    func verify(pin: String, for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] == pin }
    func containsPIN(for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] != nil }
    func removePIN(for vehicleIdentifier: String) { pins[vehicleIdentifier] = nil }
    func storedPIN(for vehicleIdentifier: String) -> String? { pins[vehicleIdentifier] }
}
