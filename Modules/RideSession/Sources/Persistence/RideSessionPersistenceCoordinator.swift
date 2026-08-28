import Foundation
import RideSessionDomain

public actor RideSessionPersistenceCoordinator {
    private let repository: any RideTripRepository
    private var queue: [QueuedOperation] = []
    private var workerTask: Task<Void, Never>?
    private var barrierWaiters: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private var flushWaiters: [CheckedContinuation<Void, Never>] = []

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func saveActiveTrip(_ trip: RideTrip) {
        if case .saveActive = queue.last?.operation {
            queue[queue.index(before: queue.endIndex)] = .init(operation: .saveActive(trip))
        } else {
            queue.append(.init(operation: .saveActive(trip)))
        }
        startWorkerIfNeeded()
    }

    @discardableResult
    public func completeTrip(_ trip: RideTrip, at date: Date) async -> Bool {
        await enqueueBarrier(.complete(trip, date))
    }

    @discardableResult
    public func resetTrip(
        completing trip: RideTrip,
        starting replacement: RideTrip?,
        at date: Date
    ) async -> Bool {
        await enqueueBarrier(.reset(trip, replacement, date))
    }

    @discardableResult
    public func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) async -> Bool {
        await enqueueBarrier(.promote(temporaryID, vin))
    }

    @discardableResult
    public func deleteCompletedTrip(id: UUID, vin: String) async -> Bool {
        await enqueueBarrier(.deleteCompleted(id, vin))
    }

    public func flush() async {
        guard workerTask != nil || !queue.isEmpty else { return }
        await withCheckedContinuation { continuation in
            flushWaiters.append(continuation)
        }
    }
}

private extension RideSessionPersistenceCoordinator {
    func enqueueBarrier(_ operation: Operation) async -> Bool {
        let id = UUID()
        return await withCheckedContinuation { continuation in
            barrierWaiters[id] = continuation
            queue.append(.init(id: id, operation: operation))
            startWorkerIfNeeded()
        }
    }

    func startWorkerIfNeeded() {
        guard workerTask == nil else { return }
        workerTask = Task { [weak self] in
            await self?.drainQueue()
        }
    }

    func drainQueue() async {
        while !queue.isEmpty {
            let queued = queue.removeFirst()
            let succeeded = await perform(queued.operation)
            if let id = queued.id {
                barrierWaiters.removeValue(forKey: id)?.resume(returning: succeeded)
            }
        }
        workerTask = nil
        let waiters = flushWaiters
        flushWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func perform(_ operation: Operation) async -> Bool {
        switch operation {
        case .saveActive(let trip):
            await repository.saveActiveTrip(trip)
        case .complete(let trip, let date):
            await repository.completeTrip(trip, at: date)
        case .reset(let trip, let replacement, let date):
            await repository.resetTrip(completing: trip, starting: replacement, at: date)
        case .promote(let temporaryID, let vin):
            await repository.promoteTemporaryIdentity(temporaryID, toVIN: vin)
        case .deleteCompleted(let id, let vin):
            await repository.deleteCompletedTrip(id: id, vin: vin)
        }
    }

    struct QueuedOperation: Sendable {
        let id: UUID?
        let operation: Operation

        init(id: UUID? = nil, operation: Operation) {
            self.id = id
            self.operation = operation
        }
    }

    enum Operation: Sendable {
        case saveActive(RideTrip)
        case complete(RideTrip, Date)
        case reset(RideTrip, RideTrip?, Date)
        case promote(UUID, String)
        case deleteCompleted(UUID, String)
    }
}
