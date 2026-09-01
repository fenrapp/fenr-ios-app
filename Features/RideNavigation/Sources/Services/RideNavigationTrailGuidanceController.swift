import Foundation
import RideNavigationDomain

@MainActor
public final class RideNavigationTrailGuidanceController {
    enum RouteStateAction {
        case none
        case announceOffRoute
        case announceWrongFork
        case announceRejoined
    }

    private let planner: any RideRouteGuidancePlanning
    let configuration: RideRouteGuidanceConfiguration

    private(set) var routeID: UUID?
    private(set) var direction: RideRouteDirection?
    private(set) var plan: RideRouteGuidancePlan?
    private(set) var session: RideRouteGuidanceSession?
    private(set) var snapshot: RideRouteGuidanceSnapshot?
    private(set) var entryPrompt: RideNavigationTrailEntryPrompt?
    private(set) var arrivalPrompt: RideNavigationArrivalPrompt?
    private(set) var isPreparing = false
    private(set) var startAfterPreparation = false
    private var didSuppressArrival = false
    private var announcedDecisionID: String?
    private var didAnnounceOffRoute = false
    private var didAnnounceWrongFork = false

    public init(
        planner: any RideRouteGuidancePlanning,
        configuration: RideRouteGuidanceConfiguration = .standard
    ) {
        self.planner = planner
        self.configuration = configuration
    }

    func makePlan(
        for route: RideRoute,
        direction: RideRouteDirection
    ) async -> RideRouteGuidancePlan? {
        await planner.makePlan(
            for: route,
            direction: direction,
            configuration: configuration
        )
    }

    func beginPreparation(
        routeID: UUID,
        direction: RideRouteDirection,
        startAfterPreparation: Bool
    ) {
        self.routeID = routeID
        self.direction = direction
        plan = nil
        session = nil
        snapshot = nil
        isPreparing = true
        self.startAfterPreparation = startAfterPreparation
    }

    func requestStartAfterPreparation() {
        startAfterPreparation = true
    }

    func acceptPreparedPlan(_ plan: RideRouteGuidancePlan?) -> Bool {
        isPreparing = false
        self.plan = plan
        let shouldStart = startAfterPreparation
        startAfterPreparation = false
        return shouldStart
    }

    func cancelPreparation() {
        isPreparing = false
        startAfterPreparation = false
    }

    func startSession(at projection: RideRouteProjection?) {
        guard let plan else { return }
        session = RideRouteGuidanceSession(
            plan: plan,
            startingAt: projection,
            configuration: configuration
        )
        snapshot = nil
        entryPrompt = nil
        arrivalPrompt = nil
        didSuppressArrival = false
        announcedDecisionID = nil
        didAnnounceOffRoute = false
        didAnnounceWrongFork = false
    }

    func update(with sample: RideRouteGuidanceSample) -> RideRouteGuidanceSnapshot? {
        guard var session, let snapshot = session.update(with: sample) else { return nil }
        self.session = session
        self.snapshot = snapshot
        return snapshot
    }

    func presentEntryPrompt(_ prompt: RideNavigationTrailEntryPrompt) {
        entryPrompt = prompt
    }

    func dismissEntryPrompt() {
        entryPrompt = nil
    }

    func presentArrivalIfNeeded(for snapshot: RideRouteGuidanceSnapshot) -> Bool {
        guard snapshot.hasReachedFinish,
              !didSuppressArrival,
              arrivalPrompt == nil else { return false }
        arrivalPrompt = RideNavigationArrivalPrompt()
        return true
    }

    func confirmArrival() -> Bool {
        guard arrivalPrompt != nil else { return false }
        arrivalPrompt = nil
        return true
    }

    func keepRidingAfterArrival() -> Bool {
        guard arrivalPrompt != nil else { return false }
        arrivalPrompt = nil
        didSuppressArrival = true
        return true
    }

    func routeStateAction(for routeState: RideRouteGuidanceRouteState) -> RouteStateAction {
        switch routeState {
        case .onRoute:
            didAnnounceOffRoute = false
            didAnnounceWrongFork = false
            return .none
        case .offRoute:
            guard !didAnnounceOffRoute else { return .none }
            didAnnounceOffRoute = true
            return .announceOffRoute
        case .wrongFork:
            guard !didAnnounceWrongFork else { return .none }
            didAnnounceWrongFork = true
            return .announceWrongFork
        case .rejoined:
            let shouldAnnounce = didAnnounceOffRoute || didAnnounceWrongFork
            didAnnounceOffRoute = false
            didAnnounceWrongFork = false
            return shouldAnnounce ? .announceRejoined : .none
        }
    }

    func shouldAnnounceDecision(_ decision: RideRouteGuidanceDecision) -> Bool {
        guard announcedDecisionID != decision.identifier else { return false }
        announcedDecisionID = decision.identifier
        return true
    }

    func reset() {
        routeID = nil
        direction = nil
        plan = nil
        session = nil
        snapshot = nil
        entryPrompt = nil
        arrivalPrompt = nil
        didSuppressArrival = false
        isPreparing = false
        startAfterPreparation = false
        announcedDecisionID = nil
        didAnnounceOffRoute = false
        didAnnounceWrongFork = false
    }
}
