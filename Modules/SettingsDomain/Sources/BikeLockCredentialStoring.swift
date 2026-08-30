public protocol BikeLockCredentialStoring: Sendable {
    func save(pin: String, for vehicleIdentifier: String) async throws
    func verify(pin: String, for vehicleIdentifier: String) async -> Bool
    func containsPIN(for vehicleIdentifier: String) async -> Bool
    func removePIN(for vehicleIdentifier: String) async throws
}

public protocol BikeLockAuthenticating: Sendable {
    func authenticate(reason: String) async throws -> Bool
}
