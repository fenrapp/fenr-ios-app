protocol BikeLockAuthenticationContext: Sendable {
    func authenticate(reason: String) async throws -> Bool
    func invalidate()
}
