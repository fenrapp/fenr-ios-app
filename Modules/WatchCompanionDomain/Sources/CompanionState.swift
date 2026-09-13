public struct CompanionState: Equatable, Sendable {
    public let snapshot: CompanionSnapshot?
    public let isReachable: Bool

    public init(snapshot: CompanionSnapshot? = nil, isReachable: Bool = false) {
        self.snapshot = snapshot
        self.isReachable = isReachable
    }
}
