import WatchConnectivity
import WatchKit

@MainActor
final class WatchCompanionAppDelegate: NSObject, WKApplicationDelegate {
    private var pendingTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    private var activationObservation: NSKeyValueObservation?
    private var contentObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching() {
        let session = WCSession.default
        activationObservation = session.observe(\.activationState) { @Sendable [weak self] _, _ in
            DispatchQueue.main.async { self?.completeTransfersIfReady() }
        }
        contentObservation = session.observe(\.hasContentPending) { @Sendable [weak self] _, _ in
            DispatchQueue.main.async { self?.completeTransfersIfReady() }
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let transfer = task as? WKWatchConnectivityRefreshBackgroundTask {
                pendingTasks.append(transfer)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
        completeTransfersIfReady()
    }

    private func completeTransfersIfReady() {
        guard WCSession.default.activationState == .activated,
              !WCSession.default.hasContentPending else { return }
        for task in pendingTasks { task.setTaskCompletedWithSnapshot(false) }
        pendingTasks.removeAll()
    }
}
