public struct AppSettingsSnapshot: Equatable, Sendable {
    public let settings: AppSettings
    public let revision: UInt64

    public init(settings: AppSettings, revision: UInt64) {
        self.settings = settings
        self.revision = revision
    }
}
