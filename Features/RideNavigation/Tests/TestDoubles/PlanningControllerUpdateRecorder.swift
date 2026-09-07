@testable import RideNavigation

@MainActor
final class PlanningControllerUpdateRecorder {
    private let stream: AsyncStream<RideNavigationPlanningUpdate>
    private var task: Task<Void, Never>?
    private(set) var updates: [RideNavigationPlanningUpdate] = []
    private(set) var isFinished = false

    init(stream: AsyncStream<RideNavigationPlanningUpdate>) {
        self.stream = stream
    }

    deinit { task?.cancel() }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, stream] in
            for await update in stream {
                guard !Task.isCancelled else { break }
                self?.updates.append(update)
            }
            self?.isFinished = true
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
