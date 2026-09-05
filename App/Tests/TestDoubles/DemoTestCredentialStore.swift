import SettingsDomain

actor DemoTestCredentialStore: BikeLockCredentialStoring {
    private var pins: [String: String] = [:]

    func save(pin: String, for vehicleIdentifier: String) { pins[vehicleIdentifier] = pin }
    func verify(pin: String, for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] == pin }
    func containsPIN(for vehicleIdentifier: String) -> Bool { pins[vehicleIdentifier] != nil }
    func removePIN(for vehicleIdentifier: String) { pins[vehicleIdentifier] = nil }
}
