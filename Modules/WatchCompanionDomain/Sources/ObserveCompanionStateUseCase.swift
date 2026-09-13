public struct ObserveCompanionStateUseCase: Sendable {
    private let session: any CompanionSession

    public init(session: any CompanionSession) {
        self.session = session
    }

    @MainActor public func execute() -> AsyncStream<CompanionState> {
        session.activate()
        return session.observe()
    }

    @MainActor public func refresh() {
        session.requestLatest()
    }
}
