import Foundation
import RideNavigationDomain

@MainActor
public final class RideNavigationPlanningController {
    var snapshot = RideNavigationPlanningSnapshot()
    let planning: RideNavigationPlanningService
    let searchService: RideNavigationSearchService
    let timing: RideNavigationTiming
    var continuation: AsyncStream<RideNavigationPlanningUpdate>.Continuation?
    var lifecycleGeneration: UInt = 0
    var contextGeneration: UInt = 0
    var generations: [RideNavigationPlanningUpdate.Channel: UInt] = [:]
    var isStarted = false
    var searchTask: Task<Void, Never>?
    var routeTask: Task<Void, Never>?
    var externalLinkTask: Task<Void, Never>?
    var trailExitTask: Task<Void, Never>?
    var lastRoadRerouteAt: Date?
    var roadRequest: RoadRequest?
    var previewPresentationPending = false

    public init(
        planning: RideNavigationPlanningService,
        search: RideNavigationSearchService,
        timing: RideNavigationTiming
    ) {
        self.planning = planning
        self.searchService = search
        self.timing = timing
    }

    deinit {
        searchTask?.cancel()
        routeTask?.cancel()
        externalLinkTask?.cancel()
        trailExitTask?.cancel()
        continuation?.finish()
    }

    func observe() -> AsyncStream<RideNavigationPlanningUpdate> {
        continuation?.finish()
        let pair = AsyncStream<RideNavigationPlanningUpdate>.makeStream()
        continuation = pair.continuation
        publish()
        return pair.stream
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        lifecycleGeneration &+= 1
    }

    func stop() {
        isStarted = false
        lifecycleGeneration &+= 1
        previewPresentationPending = false
        cancelOperations()
        continuation?.finish()
        continuation = nil
    }

    func cancelOperations() {
        for channel in RideNavigationPlanningUpdate.Channel.allCases { cancel(channel) }
        publish()
    }

    func cancel(_ channel: RideNavigationPlanningUpdate.Channel) {
        generations[channel, default: 0] &+= 1
        switch channel {
        case .search:
            searchTask?.cancel()
            searchTask = nil
            snapshot.isSearchLoading = false
        case .road:
            routeTask?.cancel()
            routeTask = nil
            roadRequest = nil
            snapshot.isPreviewSearchLoading = false
            snapshot.isCalculatingRoadRoutes = false
            snapshot.isRerouting = false
        case .externalLink:
            externalLinkTask?.cancel()
            externalLinkTask = nil
        case .trailExit:
            trailExitTask?.cancel()
            trailExitTask = nil
            snapshot.isFindingTrailExit = false
        }
    }

    func begin(_ channel: RideNavigationPlanningUpdate.Channel) -> RideNavigationPlanningUpdate.Token {
        cancel(channel)
        return .init(
            channel: channel, generation: generations[channel, default: 0],
            lifecycle: lifecycleGeneration, context: contextGeneration
        )
    }

    func isCurrent(_ token: RideNavigationPlanningUpdate.Token) -> Bool {
        token.lifecycle == lifecycleGeneration && token.context == contextGeneration
            && generations[token.channel, default: 0] == token.generation
    }

    func accepts(_ update: RideNavigationPlanningUpdate) -> Bool {
        update.contextGeneration == contextGeneration && (update.token.map(isCurrent) ?? true)
    }

    func publish(
        effect: RideNavigationPlanningUpdate.Effect? = nil,
        token: RideNavigationPlanningUpdate.Token? = nil
    ) {
        continuation?.yield(.init(
            snapshot: snapshot, contextGeneration: contextGeneration, token: token, effect: effect
        ))
    }

    func resetPlan() {
        contextGeneration &+= 1
        previewPresentationPending = false
        cancelOperations()
        snapshot.selectedRoute = nil
        snapshot.selectedDirection = .forward
        snapshot.pendingExternalDestination = nil
        clearRoadPlan()
        clearError()
    }

    func clearRoadPlan() {
        previewPresentationPending = false
        cancel(.road)
        cancel(.trailExit)
        snapshot.setRoadRoute(nil)
        snapshot.roadRoutes = []
        snapshot.selectedRoadRouteIndex = 0
        snapshot.selectedDestination = nil
        snapshot.roadNavigationPurpose = nil
        snapshot.setTrailExit(nil)
        resetRerouteThrottle()
        publish()
    }

    func cancelNavigationRequests() {
        cancel(.road)
        cancel(.trailExit)
        publish()
    }

    func beginRoadNavigation() {
        previewPresentationPending = false
        cancelNavigationRequests()
        if snapshot.roadNavigationPurpose == nil { snapshot.roadNavigationPurpose = .destination }
        publish()
    }

    func selectTrailRoute(_ route: RideRoute) {
        resetPlan()
        snapshot.selectedRoute = route
        publish()
    }

    func setDirection(_ direction: RideRouteDirection) {
        guard snapshot.selectedDirection != direction else { return }
        cancel(.road)
        cancel(.trailExit)
        snapshot.selectedDirection = direction
        snapshot.setTrailExit(nil)
        publish()
    }

    func clearError() {
        snapshot.errorMessage = nil
        publish()
    }

    func resetRerouteThrottle() {
        lastRoadRerouteAt = nil
    }

    func acknowledgePreviewPresentation(_ update: RideNavigationPlanningUpdate) {
        guard update.effect == .previewReady, accepts(update) else { return }
        previewPresentationPending = false
    }

    enum Constants {
        static let minimumSearchCharacters = 2
        static let minimumRerouteIntervalSeconds: TimeInterval = 15
    }
}
