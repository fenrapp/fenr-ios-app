struct RideNavigationPlanningUpdate: Sendable {
    enum Channel: Sendable, Hashable, CaseIterable {
        case search, road, externalLink, trailExit
    }

    enum Effect: Sendable, Equatable {
        case previewReady, previewUpdated, rerouteReady, approachReady
        case trailExitReady, externalDestinationResolved
    }

    struct Token: Sendable {
        let channel: Channel
        let generation: UInt
        let lifecycle: UInt
        let context: UInt
    }

    let snapshot: RideNavigationPlanningSnapshot
    let contextGeneration: UInt
    let token: Token?
    let effect: Effect?
}
