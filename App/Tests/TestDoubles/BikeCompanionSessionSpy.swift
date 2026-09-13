import WatchCompanionDomain

@MainActor
final class BikeCompanionSessionSpy: CompanionSnapshotPublishing {
    private(set) var snapshots: [CompanionSnapshot] = []
    private(set) var activations = 0
    func activate() { activations += 1 }
    func publish(_ snapshot: CompanionSnapshot) { snapshots.append(snapshot) }
}
