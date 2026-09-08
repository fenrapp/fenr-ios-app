@testable import RideNavigation

@MainActor
final class LibraryControllerUpdateRecorder {
    private let stream: AsyncStream<RideNavigationLibraryUpdate>
    private var task: Task<Void, Never>?
    private(set) var effects: [RideNavigationLibraryUpdate.Effect] = []
    private(set) var isFinished = false

    init(stream: AsyncStream<RideNavigationLibraryUpdate>) {
        self.stream = stream
    }

    deinit { task?.cancel() }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, stream] in
            for await update in stream {
                guard !Task.isCancelled else { break }
                if let effect = update.effect { self?.effects.append(effect) }
            }
            self?.isFinished = true
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
