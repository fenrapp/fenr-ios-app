public enum AppSettingsUpdateResult: Equatable, Sendable {
    case changed(AppSettingsSnapshot)
    case unchanged(AppSettingsSnapshot)

    public var snapshot: AppSettingsSnapshot {
        switch self {
        case let .changed(snapshot), let .unchanged(snapshot): snapshot
        }
    }
}
