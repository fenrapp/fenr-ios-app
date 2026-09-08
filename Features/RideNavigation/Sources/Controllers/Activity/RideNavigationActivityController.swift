import Foundation
import RideNavigationDomain

@MainActor
public final class RideNavigationActivityController {
    let dependencies: RideNavigationActivityDependencies
    var recorder: RideRouteRecorder
    var breadcrumbRecorder: RideRouteRecorder
    var activity = RideNavigationViewState.Activity.preview
    var completedRecording: RideRoute?
    var trailProgress: RideRouteProgress?
    var activityStartedAt: Date?
    var activeRoadStepIndex = 0
    var announcedRoadStepIndex: Int?
    var isVoiceMuted = false
    var didAnnounceOffRoute = false
    var completion: RideNavigationActivityCompletion?
    var errorMessage: String?
    var locationSnapshot = RideNavigationLocationSnapshot()
    var locationSpeed: Double?
    var preferences = RoadRoutePreferences()
    var presentationMode = RideNavigationPresentationMode.fullScreen
    var isStarted = false
    var lifecycleGeneration: UInt = 0
    var contextGeneration: UInt = 0
    var preparationGeneration: UInt = 0
    var clockGeneration: UInt = 0
    var clockTask: Task<Void, Never>?
    var trailPreparationTask: Task<Void, Never>?
    var voiceAnnouncementTask: Task<Void, Never>?
    var feedbackTask: Task<Void, Never>?
    var continuation: AsyncStream<RideNavigationActivityUpdate>.Continuation?
    var effectGeneration: UInt = 0
    var pendingEffect: RideNavigationActivityUpdate?

    public init(
        dependencies: RideNavigationActivityDependencies,
        recorder: RideRouteRecorder,
        breadcrumbRecorder: RideRouteRecorder
    ) {
        self.dependencies = dependencies
        self.recorder = recorder
        self.breadcrumbRecorder = breadcrumbRecorder
    }

    deinit {
        clockTask?.cancel()
        trailPreparationTask?.cancel()
        voiceAnnouncementTask?.cancel()
        feedbackTask?.cancel()
        continuation?.finish()
    }

    var snapshot: RideNavigationActivitySnapshot {
        let date = dependencies.timing.now()
        let recording = recorder.snapshot(at: date)
        let elapsed = activity == .recording || activity == .paused
            ? recording.activeElapsedSeconds : activityStartedAt.map { max(date.timeIntervalSince($0), 0) } ?? 0
        return .init(
            activity: activity, recording: recording, breadcrumb: breadcrumbRecorder.snapshot(at: date),
            completedRecording: completedRecording, trailProgress: trailProgress,
            activityStartedAt: activityStartedAt, elapsedSeconds: elapsed, activeRoadStepIndex: activeRoadStepIndex,
            isVoiceMuted: isVoiceMuted, didAnnounceOffRoute: didAnnounceOffRoute, completion: completion,
            trailGuidance: dependencies.trailGuidance.snapshot, trailMap: dependencies.trailMap.presentationSnapshot,
            trailOverviewCoordinates: dependencies.trailMap.overviewCoordinates,
            trailDistanceMeters: dependencies.trailMap.routeDistanceMeters, errorMessage: errorMessage
        )
    }

    func observe() -> AsyncStream<RideNavigationActivityUpdate> {
        continuation?.finish()
        let pair = AsyncStream<RideNavigationActivityUpdate>.makeStream()
        continuation = pair.continuation
        publish()
        return pair.stream
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        lifecycleGeneration &+= 1
        synchronizeClock()
        if let pending = pendingEffect,
           pending.contextGeneration == contextGeneration,
           pending.planningContextGeneration == dependencies.planning.contextGeneration,
           pending.preparationGeneration.map({ $0 == preparationGeneration }) ?? true {
            let replay = makeUpdate(effect: pending.effect, effectID: pending.effectID,
                                    preparation: pending.preparationGeneration)
            pendingEffect = replay
            continuation?.yield(replay)
        } else {
            pendingEffect = nil
            publish()
        }
    }

    func stop() {
        isStarted = false
        lifecycleGeneration &+= 1
        cancelTransientTasks()
        continuation?.finish()
        continuation = nil
    }

    func setPresentationMode(_ mode: RideNavigationPresentationMode) {
        presentationMode = mode
        synchronizeClock()
    }

    func accepts(_ update: RideNavigationActivityUpdate) -> Bool {
        update.lifecycleGeneration == lifecycleGeneration && update.contextGeneration == contextGeneration
            && update.planningContextGeneration == dependencies.planning.contextGeneration
            && (update.preparationGeneration.map { $0 == preparationGeneration } ?? true)
            && (update.effectID == nil || update.effectID == pendingEffect?.effectID)
    }

    @discardableResult
    func publish(
        effect: RideNavigationActivityUpdate.Effect? = nil,
        preparation: UInt? = nil
    ) -> RideNavigationActivityUpdate {
        if effect != nil { effectGeneration &+= 1 }
        let update = makeUpdate(effect: effect, effectID: effect == nil ? nil : effectGeneration,
                                preparation: preparation)
        if effect != nil { pendingEffect = update }
        continuation?.yield(update)
        return update
    }

    private func makeUpdate(
        effect: RideNavigationActivityUpdate.Effect?, effectID: UInt?, preparation: UInt?
    ) -> RideNavigationActivityUpdate {
        .init(
            snapshot: snapshot, lifecycleGeneration: lifecycleGeneration, contextGeneration: contextGeneration,
            planningContextGeneration: dependencies.planning.contextGeneration,
            preparationGeneration: preparation, effectID: effectID, effect: effect
        )
    }

    func acknowledgeEffect(_ update: RideNavigationActivityUpdate) {
        guard accepts(update), update.effectID != nil else { return }
        pendingEffect = nil
    }

    func cancelTransientTasks() {
        stopClock()
        preparationGeneration &+= 1
        trailPreparationTask?.cancel()
        trailPreparationTask = nil
        dependencies.trailGuidance.cancelPreparation()
        voiceAnnouncementTask?.cancel()
        voiceAnnouncementTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil
    }

    func resetForPreview() {
        contextGeneration &+= 1
        pendingEffect = nil
        cancelTransientTasks()
        activity = .preview
        completion = nil
        trailProgress = nil
        didAnnounceOffRoute = false
        dependencies.trailGuidance.reset()
        dependencies.trailMap.reset()
        resetRoadStepGuidance()
        errorMessage = nil
        publish()
    }

    func resetRoadStepGuidance() {
        activeRoadStepIndex = 0
        announcedRoadStepIndex = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func updatePreferences(_ preferences: RoadRoutePreferences) {
        self.preferences = preferences
    }

    enum Constants {
        static let arrivalDistanceMeters = 30.0
        static let roadRerouteDistanceMeters = 75.0
        static let enduroLookAheadMeters = 35.0
        static let voiceDecisionDistanceMeters = 80.0
        static let roadStepAdvanceDistanceMeters = 30.0
        static let roadStepDistanceAdvantageMeters = 10.0
    }
}
