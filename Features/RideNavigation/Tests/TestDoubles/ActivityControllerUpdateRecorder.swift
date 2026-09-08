@testable import RideNavigation

@MainActor
final class ActivityControllerUpdateRecorder {
    private let stream: AsyncStream<RideNavigationActivityUpdate>
    private var task: Task<Void, Never>?
    private(set) var updates: [RideNavigationActivityUpdate] = []
    private(set) var isFinished = false

    init(stream: AsyncStream<RideNavigationActivityUpdate>) {
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
