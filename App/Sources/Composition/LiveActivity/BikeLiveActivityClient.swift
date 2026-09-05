@preconcurrency import ActivityKit
import Foundation

@MainActor
protocol BikeLiveActivityClient: AnyObject {
    var isActive: Bool { get }
    func start(vin: String, state: BikeLiveActivityContentState) async throws
    func update(state: BikeLiveActivityContentState) async
    func end(state: BikeLiveActivityContentState) async
}

@MainActor
final class ActivityKitBikeLiveActivityClient: BikeLiveActivityClient {
    private var activity: Activity<BikeLiveActivityAttributes>?
    private let isDemo: Bool

    init(isDemo: Bool = false) {
        self.isDemo = isDemo
    }

    var isActive: Bool {
        activity != nil || !Activity<BikeLiveActivityAttributes>.activities.isEmpty
    }

    func start(vin: String, state: BikeLiveActivityContentState) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw BikeLiveActivityClientError.unavailable
        }
        if let existing = Activity<BikeLiveActivityAttributes>.activities.first {
            activity = existing
            await update(state: state)
            return
        }
        activity = try Activity.request(
            attributes: BikeLiveActivityAttributes(vin: vin),
            content: activityContent(for: state),
            pushType: nil
        )
    }

    func update(state: BikeLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.update(activityContent(for: state))
    }

    func end(state: BikeLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.end(activityContent(for: state), dismissalPolicy: isDemo ? .immediate : .default)
        self.activity = nil
    }

    private func currentActivity() -> Activity<BikeLiveActivityAttributes>? {
        if let activity { return activity }
        activity = Activity<BikeLiveActivityAttributes>.activities.first
        return activity
    }

    private func activityContent(
        for state: BikeLiveActivityContentState
    ) -> ActivityContent<BikeLiveActivityContentState> {
        var labeledState = state
        labeledState.isDemo = isDemo
        return ActivityContent(state: labeledState, staleDate: nil)
    }
}

enum BikeLiveActivityClientError: Error {
    case unavailable
}

protocol BikeLiveActivityClock: Sendable {
    var now: Date { get }
}

struct SystemBikeLiveActivityClock: BikeLiveActivityClock {
    var now: Date { Date() }
}

struct BikeLiveActivityTiming: Sendable {
    let sleep: @Sendable (Duration) async throws -> Void

    static let live = BikeLiveActivityTiming { duration in
        try await Task.sleep(for: duration)
    }
}
