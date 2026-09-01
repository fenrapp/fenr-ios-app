public enum RideNavigationRoutePersistenceState: Equatable, Sendable {
    case idle
    case saving
    case saved
    case failed(message: String)

    public var isSaving: Bool {
        if case .saving = self { return true }
        return false
    }
}
