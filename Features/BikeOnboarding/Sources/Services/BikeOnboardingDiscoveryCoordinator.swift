import BikeDomain
import Foundation
import RuntimeConfiguration

enum BikeOnboardingDiscoveryEvent: Sendable {
    case started
    case updated(bikes: [BikeDiscoveryViewData], state: BikeOnboardingDiscoveryState)
    case selected(BikeDiscoveryViewData)
    case timedOut
}

@MainActor
public final class BikeOnboardingDiscoveryCoordinator {
    let events: AsyncStream<BikeOnboardingDiscoveryEvent>

    private let repositoryStarter: BikeOnboardingRepositoryStarter
    private let startDiscovery: StartBikeDiscoveryUseCase
    private let stopDiscovery: StopBikeDiscoveryUseCase
    private let observeDiscoveredBikes: ObserveDiscoveredBikesUseCase
    private let mapper: BikeOnboardingPresentationMapper
    private let timing: BikeOnboardingTiming
    private let eventContinuation: AsyncStream<BikeOnboardingDiscoveryEvent>.Continuation

    private var scanTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var selectionVIN: String?
    private var attemptID: UUID?
    private var signalsByVIN: [String: Int] = [:]
    private var isActive = false

    public init(
        repositoryStarter: BikeOnboardingRepositoryStarter,
        startDiscovery: StartBikeDiscoveryUseCase,
        stopDiscovery: StopBikeDiscoveryUseCase,
        observeDiscoveredBikes: ObserveDiscoveredBikesUseCase,
        mapper: BikeOnboardingPresentationMapper,
        timing: BikeOnboardingTiming
    ) {
        self.repositoryStarter = repositoryStarter
        self.startDiscovery = startDiscovery
        self.stopDiscovery = stopDiscovery
        self.observeDiscoveredBikes = observeDiscoveredBikes
        self.mapper = mapper
        self.timing = timing
        let eventChannel = AsyncStream<BikeOnboardingDiscoveryEvent>.makeStream()
        events = eventChannel.stream
        eventContinuation = eventChannel.continuation
    }

    deinit {
        scanTask?.cancel()
        timeoutTask?.cancel()
        selectionTask?.cancel()
        eventContinuation.finish()
    }

    func start() {
        let pendingStop = stop()
        let currentAttemptID = UUID()
        attemptID = currentAttemptID
        signalsByVIN = [:]
        isActive = true
        eventContinuation.yield(.started)

        let pendingRepositoryStart = repositoryStarter.start()
        let observeDiscoveredBikes = observeDiscoveredBikes
        let startDiscovery = startDiscovery
        scanTask = Task { [weak self] in
            await pendingStop?.value
            await pendingRepositoryStart.value
            guard !Task.isCancelled, self?.attemptID == currentAttemptID else { return }
            let discoveredBikes = await observeDiscoveredBikes.execute()
            guard !Task.isCancelled, self?.attemptID == currentAttemptID else { return }
            await startDiscovery.execute()
            guard !Task.isCancelled, let self, self.attemptID == currentAttemptID else { return }
            self.scheduleTimeout(for: currentAttemptID)
            for await bikes in discoveredBikes {
                guard !Task.isCancelled, self.attemptID == currentAttemptID else { return }
                self.receive(bikes, attemptID: currentAttemptID)
            }
        }
    }

    @discardableResult
    func stop() -> Task<Void, Never>? {
        stopScan(invalidateAttempt: true)
    }

    private func receive(_ discoveredBikes: [DiscoveredBike], attemptID: UUID) {
        guard isActive, self.attemptID == attemptID else { return }
        if discoveredBikes.isEmpty {
            signalsByVIN.removeAll()
        }
        for bike in discoveredBikes {
            signalsByVIN[bike.vin] = bike.rssi
        }
        let bikes = signalsByVIN
            .map { DiscoveredBike(vin: $0.key, rssi: $0.value) }
            .map(mapper.discoveryViewData)
            .sorted { lhs, rhs in
                if lhs.signalLevel == rhs.signalLevel { return lhs.vin < rhs.vin }
                return lhs.signalLevel > rhs.signalLevel
            }

        if bikes.isEmpty {
            scheduleTimeout(for: attemptID)
        } else {
            timeoutTask?.cancel()
            timeoutTask = nil
        }

        let state: BikeOnboardingDiscoveryState = switch bikes.count {
        case .zero: .scanning
        case 1: .stabilizing
        default: .multiple
        }
        eventContinuation.yield(.updated(bikes: bikes, state: state))
        scheduleSelection(for: bikes, attemptID: attemptID)
    }

    private func scheduleTimeout(for attemptID: UUID) {
        guard timeoutTask == nil, isActive, self.attemptID == attemptID, signalsByVIN.isEmpty else { return }
        let timing = timing
        timeoutTask = Task { [weak self] in
            do {
                try await timing.sleep(FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  let self,
                  self.isActive,
                  self.attemptID == attemptID,
                  self.signalsByVIN.isEmpty else { return }
            let pendingStop = self.stopScan(invalidateAttempt: false)
            await pendingStop?.value
            guard !Task.isCancelled, self.attemptID == attemptID else { return }
            self.timeoutTask = nil
            self.attemptID = nil
            self.eventContinuation.yield(.timedOut)
        }
    }

    private func scheduleSelection(for bikes: [BikeDiscoveryViewData], attemptID: UUID) {
        guard bikes.count == 1, let candidate = bikes.first else {
            cancelSelection()
            return
        }
        guard selectionVIN != candidate.vin || selectionTask == nil else { return }
        selectionTask?.cancel()
        selectionVIN = candidate.vin
        let timing = timing
        selectionTask = Task { [weak self] in
            do {
                try await timing.sleep(FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  let self,
                  self.isActive,
                  self.attemptID == attemptID,
                  self.selectionVIN == candidate.vin,
                  self.signalsByVIN.count == 1,
                  self.signalsByVIN[candidate.vin] != nil else { return }
            self.selectionTask = nil
            self.selectionVIN = nil
            self.eventContinuation.yield(.selected(candidate))
        }
    }

    @discardableResult
    private func stopScan(invalidateAttempt: Bool) -> Task<Void, Never>? {
        guard isActive || scanTask != nil else {
            if invalidateAttempt {
                cancelTimeout()
            }
            return stopTask
        }
        isActive = false
        if invalidateAttempt {
            cancelTimeout()
        }
        cancelSelection()
        let previousScan = scanTask
        scanTask?.cancel()
        scanTask = nil
        let previousStop = stopTask
        let stopDiscovery = stopDiscovery
        let task = Task {
            await previousStop?.value
            await previousScan?.value
            guard !Task.isCancelled else { return }
            await stopDiscovery.execute()
        }
        stopTask = task
        return task
    }

    private func cancelSelection() {
        selectionTask?.cancel()
        selectionTask = nil
        selectionVIN = nil
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
        attemptID = nil
    }
}
