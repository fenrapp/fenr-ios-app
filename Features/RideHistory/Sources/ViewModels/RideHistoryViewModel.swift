import Combine
import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain

@MainActor
public final class RideHistoryViewModel: ObservableObject {
    @Published public private(set) var viewState = RideHistoryViewState()
    @Published public private(set) var detailViewState = RideHistoryDetailViewState()

    private let useCases: RideHistoryUseCases
    private let session: any RideSessionService
    private let mapper: RideHistoryMapper
    private var trips: [RideTrip] = []
    private var detailTrip: RideTrip?
    private var activeVIN: String?
    private var measurementSystem: MeasurementSystem = .system
    private var requestedHistoryKey: HistoryKey?
    private var loadedHistoryKey: HistoryKey?
    private var observationTask: Task<Void, Never>?
    private var historyLoadTask: Task<Void, Never>?
    private var detailLoadTask: Task<Void, Never>?
    private var deleteTask: Task<Void, Never>?
    private var deletingRideIDs: Set<UUID> = []
    private var errorMessage: String?

    public init(
        useCases: RideHistoryUseCases,
        session: any RideSessionService,
        mapper: RideHistoryMapper
    ) {
        self.useCases = useCases
        self.session = session
        self.mapper = mapper
    }

    deinit {
        observationTask?.cancel()
        historyLoadTask?.cancel()
        detailLoadTask?.cancel()
        deleteTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self, session] in
            let stream = await session.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        historyLoadTask?.cancel()
        historyLoadTask = nil
        requestedHistoryKey = nil
    }

    public func refresh() {
        loadedHistoryKey = nil
        loadHistoryIfNeeded(force: true)
    }

    public func loadDetail(id: UUID) {
        guard let vin = activeVIN else {
            detailViewState = .init(status: .unavailable, rideID: id)
            return
        }
        detailLoadTask?.cancel()
        detailTrip = nil
        detailViewState = .init(status: .loading, rideID: id)
        let loadDetail = useCases.loadDetail
        detailLoadTask = Task { [weak self] in
            let trip = await loadDetail.execute(id: id, vin: vin)
            guard !Task.isCancelled, let self, self.activeVIN == vin,
                  self.detailViewState.rideID == id else { return }
            self.detailLoadTask = nil
            guard let trip else {
                self.detailViewState = .init(status: .unavailable, rideID: id)
                return
            }
            self.detailTrip = trip
            self.renderDetail()
        }
    }

    public func clearDetail(id: UUID) {
        guard detailViewState.rideID == id else { return }
        detailLoadTask?.cancel()
        detailLoadTask = nil
        detailTrip = nil
        detailViewState = .init()
    }

    public func deleteRide(id: UUID) {
        deleteRides(ids: [id])
    }

    public func deleteRides(ids: Set<UUID>) {
        guard deleteTask == nil,
              let vin = activeVIN else { return }
        let orderedIDs = trips.map(\.id).filter(ids.contains)
        guard !orderedIDs.isEmpty else { return }
        deletingRideIDs = Set(orderedIDs)
        errorMessage = nil
        renderList()
        let session = session
        deleteTask = Task { [weak self] in
            var deletedIDs: Set<UUID> = []
            for id in orderedIDs {
                guard !Task.isCancelled else { return }
                if await session.deleteCompletedTrip(id: id, vin: vin) {
                    deletedIDs.insert(id)
                }
            }
            guard !Task.isCancelled, let self, self.activeVIN == vin else { return }
            self.deleteTask = nil
            self.deletingRideIDs = []
            self.trips.removeAll { deletedIDs.contains($0.id) }
            if deletedIDs.count != orderedIDs.count {
                self.errorMessage = orderedIDs.count == 1
                    ? "The ride could not be deleted. Please try again."
                    : "Some rides could not be deleted. Please try again."
            }
            self.loadedHistoryKey = nil
            self.renderList()
            self.loadHistoryIfNeeded(force: true)
        }
    }

    public func dismissError() {
        errorMessage = nil
        renderList()
    }
}

private extension RideHistoryViewModel {
    func receive(_ snapshot: RideSessionSnapshot) {
        let previousVIN = activeVIN
        let previousMeasurementSystem = measurementSystem
        activeVIN = snapshot.vehicleIdentity.confirmedVIN
        measurementSystem = snapshot.measurementSystem

        guard let activeVIN else {
            resetHistory(for: .bikeUnavailable)
            return
        }

        if previousVIN != activeVIN {
            resetHistory(for: .loading)
        } else if previousMeasurementSystem != measurementSystem {
            renderList()
            renderDetail()
        }

        let key = HistoryKey(vin: activeVIN, revision: snapshot.historyRevision)
        if requestedHistoryKey != key {
            requestedHistoryKey = key
            loadedHistoryKey = nil
        }
        loadHistoryIfNeeded(force: false)
    }

    func loadHistoryIfNeeded(force: Bool) {
        guard let key = requestedHistoryKey ?? activeVIN.map({ HistoryKey(vin: $0, revision: .zero) }) else {
            viewState = .init(status: .bikeUnavailable)
            return
        }
        guard force || loadedHistoryKey != key else { return }
        guard force || deleteTask == nil else { return }
        historyLoadTask?.cancel()
        if trips.isEmpty {
            viewState = .init(status: .loading, errorMessage: errorMessage)
        }
        let loadHistory = useCases.loadHistory
        historyLoadTask = Task { [weak self] in
            let loadedTrips = await loadHistory.execute(vin: key.vin)
            guard !Task.isCancelled, let self, self.activeVIN == key.vin else { return }
            self.historyLoadTask = nil
            self.trips = loadedTrips.sorted { $0.startedAt > $1.startedAt }
            self.loadedHistoryKey = self.requestedHistoryKey ?? key
            self.renderList()
            self.renderDetail()
        }
    }

    func renderList() {
        guard activeVIN != nil else {
            viewState = .init(status: .bikeUnavailable, errorMessage: errorMessage)
            return
        }
        viewState = mapper.mapList(
            trips: trips,
            measurementSystem: measurementSystem,
            deletingRideIDs: deletingRideIDs,
            errorMessage: errorMessage
        )
    }

    func renderDetail() {
        guard let detailTrip else { return }
        detailViewState = mapper.mapDetail(
            trip: detailTrip,
            history: trips,
            measurementSystem: measurementSystem
        )
    }

    func resetHistory(for status: RideHistoryViewState.Status) {
        historyLoadTask?.cancel()
        historyLoadTask = nil
        detailLoadTask?.cancel()
        detailLoadTask = nil
        deleteTask?.cancel()
        deleteTask = nil
        trips = []
        detailTrip = nil
        deletingRideIDs = []
        errorMessage = nil
        loadedHistoryKey = nil
        requestedHistoryKey = nil
        viewState = .init(status: status)
        detailViewState = .init()
    }

    struct HistoryKey: Equatable {
        let vin: String
        let revision: Int
    }
}
