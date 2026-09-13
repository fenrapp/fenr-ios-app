@MainActor
public protocol CompanionSnapshotPublishing: AnyObject, Sendable {
    func activate()
    func publish(_ snapshot: CompanionSnapshot)
}
