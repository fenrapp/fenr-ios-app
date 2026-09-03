import Foundation
import RideNavigationDomain

@MainActor
final class IncomingMapLinkController {
    private let store: any IncomingMapLinkStoring
    private let resolver: AppExternalNavigationResolver
    private let onRequest: @MainActor (AppExternalNavigationRequest) -> Void
    private var consumeTask: Task<Void, Never>?
    private var consumeID: UUID?
    private var didConsume = false

    init(
        store: any IncomingMapLinkStoring,
        resolver: AppExternalNavigationResolver,
        onRequest: @escaping @MainActor (AppExternalNavigationRequest) -> Void
    ) {
        self.store = store
        self.resolver = resolver
        self.onRequest = onRequest
    }

    deinit {
        consumeTask?.cancel()
    }

    func consume() async {
        guard !didConsume else { return }
        if let consumeTask {
            await consumeTask.value
            return
        }

        let consumeID = UUID()
        self.consumeID = consumeID
        let task = Task { @MainActor [weak self, store, resolver, onRequest] in
            do {
                let link = try await store.consume()
                guard let self, !Task.isCancelled else { return }
                didConsume = true
                if let link, let request = resolver.resolve(link.url) {
                    onRequest(request)
                }
            } catch {
                // Consumption remains retryable after transient storage failures.
            }
            if self?.consumeID == consumeID {
                self?.consumeTask = nil
                self?.consumeID = nil
            }
        }
        consumeTask = task
        await task.value
    }

    func cancel() {
        consumeTask?.cancel()
        consumeTask = nil
        consumeID = nil
    }
}
