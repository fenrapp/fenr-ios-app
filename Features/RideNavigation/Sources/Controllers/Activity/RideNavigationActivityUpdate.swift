struct RideNavigationActivityUpdate: Sendable {
    struct TerminalContext: Sendable {
        let activity: RideNavigationActivitySnapshot
        let planning: RideNavigationPlanningSnapshot
        let location: RideNavigationLocationSnapshot
        let completion: RideNavigationActivityCompletion
    }

    enum Effect: Sendable {
        case showActiveMap
        case showTrailOverview
        case completed(TerminalContext)
    }

    let snapshot: RideNavigationActivitySnapshot
    let lifecycleGeneration: UInt
    let contextGeneration: UInt
    let planningContextGeneration: UInt
    let preparationGeneration: UInt?
    let effectID: UInt?
    let effect: Effect?
}
