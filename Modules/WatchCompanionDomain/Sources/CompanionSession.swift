@MainActor
public protocol CompanionSession: AnyObject, Sendable {
    func activate()
    func observe() -> AsyncStream<CompanionState>
    func requestLatest()
}
