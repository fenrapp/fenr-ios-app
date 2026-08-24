@preconcurrency import ActivityKit
import Foundation

@MainActor
protocol BikeLiveActivityClient: AnyObject {
    var isActive: Bool { get }
    func start(vin: String, state: BikeLiveActivityContentState) async throws
    func update(state: BikeLiveActivityContentState) async
    func end(state: BikeLiveActivityContentState) async
}

@available(iOS 16.1, *)
@MainActor
final class ActivityKitBikeLiveActivityClient: BikeLiveActivityClient {
    private var activity: Activity<BikeLiveActivityAttributes>?

    var isActive: Bool {
        guard #available(iOS 16.1, *) else { return false }
        return activity != nil || !Activity<BikeLiveActivityAttributes>.activities.isEmpty
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
            contentState: state,
            pushType: nil
        )
    }

    func update(state: BikeLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.update(using: state)
    }

    func end(state: BikeLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.end(using: state, dismissalPolicy: .default)
        self.activity = nil
    }

    private func currentActivity() -> Activity<BikeLiveActivityAttributes>? {
        if let activity { return activity }
        activity = Activity<BikeLiveActivityAttributes>.activities.first
        return activity
    }
}

@MainActor
final class NoOpBikeLiveActivityClient: BikeLiveActivityClient {
    var isActive: Bool { false }
    func start(vin: String, state: BikeLiveActivityContentState) async throws {
        throw BikeLiveActivityClientError.unavailable
    }
    func update(state: BikeLiveActivityContentState) async {}
    func end(state: BikeLiveActivityContentState) async {}
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
