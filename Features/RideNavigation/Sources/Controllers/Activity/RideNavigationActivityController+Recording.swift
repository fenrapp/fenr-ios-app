import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationActivityController {
    @discardableResult
    func startRecording(name: String) -> RideNavigationActivityUpdate {
        resetForPreview()
        dependencies.library.resetPersistence()
        dependencies.planning.resetPlan()
        let date = dependencies.timing.now()
        recorder.start(at: date, name: name)
        completedRecording = nil
        activityStartedAt = date
        activity = .recording
        synchronizeClock()
        announce(String(localized: .rideNavigationAnnouncementRecordingStarted))
        return publish(effect: .showActiveMap)
    }

    func toggleRecordingPause() {
        let date = dependencies.timing.now()
        switch activity {
        case .recording:
            recorder.pause(at: date)
            activity = .paused
            scheduleDraftSave()
            announce(String(localized: .rideNavigationAnnouncementRecordingPaused))
        case .paused:
            recorder.resume(at: date)
            activity = .recording
            announce(String(localized: .rideNavigationAnnouncementRecordingResumed))
        default: return
        }
        publish()
    }

    @discardableResult
    func finishActivity() -> RideNavigationActivityUpdate? {
        let reason: RideNavigationCompletionReason
        switch activity {
        case .recording, .paused: reason = .rideRecorded
        case .following: reason = .trailEnded
        case .navigating where dependencies.planning.snapshot.roadNavigationPurpose == .trailExit:
            reason = .exitNavigationEnded
        case .navigating: reason = .navigationEnded
        case .preview: return nil
        }
        return finishActivity(reason: reason)
    }

    @discardableResult
    func finishActivity(reason: RideNavigationCompletionReason) -> RideNavigationActivityUpdate? {
        guard snapshot.hasActiveSession else { return nil }
        dependencies.planning.cancelNavigationRequests()
        let date = dependencies.timing.now()
        let before = snapshot
        let planning = dependencies.planning.snapshot
        var distance = planning.roadRoute?.distanceMeters ?? before.trailDistanceMeters
        var hasPoints = true
        var autoSave: RideRoute?
        if reason == .rideRecorded {
            completedRecording = recorder.finish(at: date)
            distance = completedRecording?.distanceMeters ?? 0
            hasPoints = completedRecording != nil
            dependencies.library.clearDraft()
        } else if activity == .following {
            if let breadcrumb = breadcrumbRecorder.finish(at: date) {
                let route = RideRoute(
                    name: String(localized: .rideNavigationRideWithTrailName(
                        planning.selectedRoute?.name ?? String(localized: .rideNavigationTrailName)
                    )),
                    createdAt: breadcrumb.createdAt, updatedAt: date, segments: breadcrumb.segments
                )
                completedRecording = route
                distance = route.distanceMeters
                autoSave = route
            } else {
                completedRecording = nil
                dependencies.library.resetPersistence()
                hasPoints = false
            }
        } else if activity == .navigating {
            _ = breadcrumbRecorder.finish(at: date)
        }
        let completed = RideNavigationActivityCompletion(
            reason: reason, isSuccessful: reason != .rideRecorded || hasPoints, hasGPSPoints: hasPoints,
            distanceFirst: reason == .rideRecorded || activity == .following,
            distanceMeters: distance, elapsedSeconds: before.elapsedSeconds
        )
        completion = completed
        activityStartedAt = nil
        activity = .preview
        stopClock()
        if reason.emitsSuccessFeedback, completed.isSuccessful { notifySuccess() }
        if let autoSave { dependencies.library.saveCompletedRoute(autoSave) }
        return publish(effect: .completed(.init(
            activity: before, planning: planning, location: locationSnapshot, completion: completed
        )))
    }

    func discardActivity() {
        guard !dependencies.library.snapshot.persistence.status.isSaving else { return }
        recorder.reset()
        breadcrumbRecorder.reset()
        completedRecording = nil
        activityStartedAt = nil
        resetForPreview()
        dependencies.library.resetPersistence()
        dependencies.planning.resetPlan()
        dependencies.library.clearDraft()
        publish()
    }

    func saveCompletedRoute(name: String, closeAfterSave: Bool = false) {
        guard let completedRecording, !dependencies.library.snapshot.persistence.status.isSaving else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = completedRecording.renamed(
            trimmed.isEmpty ? completedRecording.name : trimmed, at: dependencies.timing.now()
        )
        self.completedRecording = route
        dependencies.library.saveCompletedRoute(route, closeAfterSave: closeAfterSave)
        publish()
    }

    func startBreadcrumb(at date: Date) {
        breadcrumbRecorder.reset()
        breadcrumbRecorder.start(at: date, name: String(localized: .rideNavigationBreadcrumbName))
        trailProgress = nil
        didAnnounceOffRoute = false
        dependencies.planning.resetRerouteThrottle()
        if let point = dependencies.locationGeometry.routePoint(from: locationSnapshot) {
            breadcrumbRecorder.append(point)
        }
    }

    @discardableResult
    func beginRoadNavigation(isApproach: Bool = false) -> RideNavigationActivityUpdate {
        let date = dependencies.timing.now()
        startBreadcrumb(at: date)
        activityStartedAt = date
        completion = nil
        activity = .navigating
        resetRoadStepGuidance()
        dependencies.planning.beginRoadNavigation()
        synchronizeClock()
        announce(String(localized: isApproach
            ? .rideNavigationAnnouncementTrailApproachStarted : .rideNavigationAnnouncementRoadStarted))
        return publish(effect: .showActiveMap)
    }

    func stopNavigationWithoutSummary() {
        dependencies.planning.clearRoadPlan()
        if activity == .following || activity == .navigating {
            _ = breadcrumbRecorder.finish(at: dependencies.timing.now())
        }
        activityStartedAt = nil
        activity = .preview
        trailProgress = nil
        resetRoadStepGuidance()
        didAnnounceOffRoute = false
        stopClock()
        publish()
    }

    func continueRoadNavigation() {
        activity = .navigating
        resetRoadStepGuidance()
        publish()
    }

    func resumeTrailFollowing() {
        activity = .following
        trailProgress = nil
        didAnnounceOffRoute = false
        if !dependencies.trailGuidance.snapshot.hasActiveSession { dependencies.trailGuidance.startSession(at: nil) }
        if let sample = trailGuidanceSample { updateTrailGuidance(with: sample) }
        publish()
    }

    func scheduleDraftSave() {
        guard let route = recorder.snapshot(at: dependencies.timing.now()).route else { return }
        dependencies.library.scheduleDraft(route)
    }
}
