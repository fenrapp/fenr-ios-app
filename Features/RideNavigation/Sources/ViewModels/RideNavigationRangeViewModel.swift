import Foundation
import Observation
import RideSession
import RideSessionDomain

@MainActor
@Observable
public final class RideNavigationRangeViewModel {
    public private(set) var state = RideNavigationRangeState()
    private let session: any RideSessionService
    private let loadHistory: LoadRideTripRangeHistoryUseCase
    private let mapper: RideNavigationRangeMapper
    @ObservationIgnored private var snapshot: RideSessionSnapshot?
    @ObservationIgnored private var history: [RideTrip] = []
    @ObservationIgnored private var requestedKey: HistoryKey?
    @ObservationIgnored private var generation: UInt = 0
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var historyTask: Task<Void, Never>?

    public init(
        session: any RideSessionService,
        loadHistory: LoadRideTripRangeHistoryUseCase,
        mapper: RideNavigationRangeMapper
    ) {
        self.session = session
        self.loadHistory = loadHistory
        self.mapper = mapper
    }

    deinit {
        observationTask?.cancel()
        historyTask?.cancel()
    }

    func start() {
        guard observationTask == nil else { return }
        generation &+= 1
        let currentGeneration = generation
        observationTask = Task { [weak self, session] in
            let stream = await session.observe()
            for await snapshot in stream {
                guard !Task.isCancelled, let self, generation == currentGeneration else { return }
                receive(snapshot)
            }
        }
    }

    func stop() {
        generation &+= 1
        observationTask?.cancel()
        observationTask = nil
        historyTask?.cancel()
        historyTask = nil
        requestedKey = nil
        snapshot = nil
        history = []
        state = RideNavigationRangeState()
    }

#if DEBUG
    var historyLoadTaskForTesting: Task<Void, Never>? { historyTask }
#endif

    private func receive(_ snapshot: RideSessionSnapshot) {
        if self.snapshot?.vehicleIdentity != snapshot.vehicleIdentity {
            historyTask?.cancel()
            historyTask = nil
            requestedKey = nil
            history = []
        }
        self.snapshot = snapshot
        render()
        guard let vin = snapshot.vehicleIdentity.confirmedVIN else { return }
        let key = HistoryKey(vin: vin, revision: snapshot.historyRevision)
        guard key != requestedKey else { return }
        historyTask?.cancel()
        requestedKey = key
        let currentGeneration = generation
        historyTask = Task { [weak self, loadHistory] in
            let trips = try? await loadHistory.execute(vin: vin)
            guard !Task.isCancelled, let self,
                  generation == currentGeneration, requestedKey == key else { return }
            if let trips { history = trips }
            historyTask = nil
            render()
        }
    }

    private func render() {
        guard let snapshot else { return }
        state = mapper.map(snapshot: snapshot, history: history)
    }

    private struct HistoryKey: Equatable {
        let vin: String
        let revision: Int
    }
}
