import Foundation

public protocol CompanionSnapshotStoring: Sendable {
    func load() -> Data?
    func save(_ data: Data)
}

public final class CompanionSnapshotStore: CompanionSnapshotStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults, key: String) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Data? { defaults.data(forKey: key) }
    public func save(_ data: Data) { defaults.set(data, forKey: key) }
}
