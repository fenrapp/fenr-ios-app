import Foundation
import Observation

@MainActor
@Observable
final class PowerModeOperationController {
    enum Operation { case refresh, preparation, basicWrite, advancedRead, advancedWrite }
    private(set) var active: Operation?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    var isBusy: Bool { active != nil }
    var isWriting: Bool { active == .basicWrite || active == .advancedWrite }

    deinit { task?.cancel() }

    func run<Value: Sendable>(
        _ operation: Operation,
        execute: @escaping @Sendable () async throws -> Value,
        completion: @escaping @MainActor (Result<Value, any Error>) -> Void
    ) {
        guard task == nil else { return }
        generation += 1
        let token = generation
        active = operation
        task = Task { [weak self] in
            let result: Result<Value, any Error>
            do { result = .success(try await execute()) } catch { result = .failure(error) }
            guard !Task.isCancelled, let self, token == self.generation else { return }
            self.task = nil
            self.active = nil
            completion(result)
        }
    }

    @discardableResult
    func cancel() -> Task<Void, Never>? {
        generation += 1
        let pending = task
        pending?.cancel()
        task = nil
        active = nil
        return pending
    }
}
