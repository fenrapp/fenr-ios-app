import Foundation
import RideNavigationDomain

@MainActor
public final class RideNavigationTrailGuidanceController {
    struct Snapshot: Sendable {
        let routeID: UUID?
        let direction: RideRouteDirection?
        let plan: RideRouteGuidancePlan?
        let guidance: RideRouteGuidanceSnapshot?
        let entryPrompt: RideNavigationTrailEntryPrompt?
        let arrivalPrompt: RideNavigationArrivalPrompt?
        let isPreparing: Bool
        let hasActiveSession: Bool
    }

    enum RouteStateAction {
        case none
        case announceOffRoute
        case announceWrongFork
        case announceRejoined
    }

    private let planner: any RideRouteGuidancePlanning
    private let configuration: RideRouteGuidanceConfiguration

    private var routeID: UUID?
    private var direction: RideRouteDirection?
    private var plan: RideRouteGuidancePlan?
    private var session: RideRouteGuidanceSession?
    private var guidance: RideRouteGuidanceSnapshot?
    private var entryPrompt: RideNavigationTrailEntryPrompt?
    private var arrivalPrompt: RideNavigationArrivalPrompt?
    private var isPreparing = false
    private var startAfterPreparation = false
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

    var snapshot: Snapshot {
        Snapshot(
            routeID: routeID,
            direction: direction,
            plan: plan,
            guidance: guidance,
            entryPrompt: entryPrompt,
            arrivalPrompt: arrivalPrompt,
            isPreparing: isPreparing,
            hasActiveSession: session != nil
        )
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
        guidance = nil
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
        guidance = nil
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
        guidance = snapshot
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
        guidance = nil
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
