import Foundation
import Observation
import RideSession
import RideSessionDomain
import SettingsDomain

@MainActor
@Observable
public final class RideHistoryViewModel {
    public private(set) var viewState = RideHistoryViewState()
    public private(set) var detailViewState = RideHistoryDetailViewState()

    private let useCases: RideHistoryUseCases
    private let session: any RideSessionService
    private let mapper: RideHistoryMapper
    @ObservationIgnored private var trips: [RideTrip] = []
    @ObservationIgnored private var detailTrip: RideTrip?
    @ObservationIgnored private var activeVIN: String?
    @ObservationIgnored private var measurementSystem: MeasurementSystem = .system
    @ObservationIgnored private var requestedHistoryKey: HistoryKey?
    @ObservationIgnored private var loadedHistoryKey: HistoryKey?
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var historyLoadTask: Task<Void, Never>?
    @ObservationIgnored private var historyLoadID: UUID?
    @ObservationIgnored private var detailLoadTask: Task<Void, Never>?
    @ObservationIgnored private var detailLoadID: UUID?
    @ObservationIgnored private var deleteTask: Task<Void, Never>?
    @ObservationIgnored private var deleteID: UUID?
    @ObservationIgnored private var deletingRideIDs: Set<UUID> = []
    @ObservationIgnored private var errorMessage: String?
    @ObservationIgnored private var loadErrorMessage: String?
    @ObservationIgnored private var detailLoadErrorMessage: String?
    @ObservationIgnored private var hasLoadedHistory = false
    @ObservationIgnored private var failedHistoryKey: HistoryKey?

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

    public func stopAndWait() async {
        let tasks = [observationTask, historyLoadTask, detailLoadTask, deleteTask]
        tasks.forEach { $0?.cancel() }
        stop()
        detailLoadTask = nil
        detailLoadID = nil
        for task in tasks { await task?.value }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        historyLoadTask?.cancel()
        historyLoadTask = nil
        historyLoadID = nil
        requestedHistoryKey = nil
        // The presented detail owns its load beyond the list's visible lifetime.
    }

    public func refresh() {
        guard deleteTask == nil else { return }
        loadedHistoryKey = nil
        failedHistoryKey = nil
        loadHistoryIfNeeded(force: true)
    }

    public func loadDetail(id: UUID) {
        guard let vin = activeVIN else {
            detailViewState = .init(status: .unavailable, rideID: id)
            return
        }
        detailLoadTask?.cancel()
        let operationID = UUID()
        detailLoadID = operationID
        detailLoadErrorMessage = nil
        if detailTrip?.id != id {
            detailTrip = nil
            detailViewState = .init(status: .loading, rideID: id)
        } else {
            renderDetail()
        }
        let loadDetail = useCases.loadDetail
        detailLoadTask = Task { [weak self] in
            do {
                let trip = try await loadDetail.execute(id: id, vin: vin)
                guard !Task.isCancelled, let self, self.activeVIN == vin,
                      self.detailViewState.rideID == id, self.detailLoadID == operationID else { return }
                self.detailLoadTask = nil
                self.detailLoadID = nil
                self.detailTrip = trip
                guard trip != nil else {
                    self.detailViewState = .init(status: .unavailable, rideID: id)
                    return
                }
                self.renderDetail()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, self.activeVIN == vin,
                      self.detailViewState.rideID == id, self.detailLoadID == operationID else { return }
                self.detailLoadTask = nil
                self.detailLoadID = nil
                self.detailLoadErrorMessage = String(localized: .rideHistoryDetailReadError)
                if self.detailTrip != nil {
                    self.renderDetail()
                } else {
                    self.detailViewState = .init(
                        status: .failed, rideID: id, loadErrorMessage: self.detailLoadErrorMessage
                    )
                }
            }
        }
    }

    public func clearDetail(id: UUID) {
        guard detailViewState.rideID == id else { return }
        detailLoadTask?.cancel()
        detailLoadTask = nil
        detailLoadID = nil
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
        let operationID = UUID()
        deleteID = operationID
        deleteTask = Task { [weak self] in
            var deletedIDs: Set<UUID> = []
            for id in orderedIDs {
                guard !Task.isCancelled else { return }
                if await session.deleteCompletedTrip(id: id, vin: vin) {
                    deletedIDs.insert(id)
                }
            }
            guard !Task.isCancelled, let self, self.activeVIN == vin,
                  self.deleteID == operationID else { return }
            self.deleteTask = nil
            self.deleteID = nil
            self.deletingRideIDs = []
            self.trips.removeAll { deletedIDs.contains($0.id) }
            if deletedIDs.count != orderedIDs.count {
                self.errorMessage = orderedIDs.count == 1
                    ? String(localized: .rideHistoryDeleteSingleError)
                    : String(localized: .rideHistoryDeleteMultipleError)
            }
            self.loadedHistoryKey = nil
            self.renderList()
            if self.requestedHistoryKey != nil {
                self.loadHistoryIfNeeded(force: true)
            }
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
            historyLoadTask?.cancel()
            historyLoadTask = nil
            historyLoadID = nil
            requestedHistoryKey = key
            loadedHistoryKey = nil
            failedHistoryKey = nil
        }
        loadHistoryIfNeeded(force: false)
    }

    func loadHistoryIfNeeded(force: Bool) {
        guard let key = requestedHistoryKey ?? activeVIN.map({ HistoryKey(vin: $0, revision: .zero) }) else {
            viewState = .init(status: .bikeUnavailable)
            return
        }
        guard force || (loadedHistoryKey != key && failedHistoryKey != key) else { return }
        guard force || historyLoadTask == nil else { return }
        guard deleteTask == nil else { return }
        historyLoadTask?.cancel()
        let operationID = UUID()
        historyLoadID = operationID
        loadErrorMessage = nil
        if !hasLoadedHistory {
            viewState = .init(status: .loading, errorMessage: errorMessage)
        } else {
            renderList()
        }
        let loadHistory = useCases.loadHistory
        historyLoadTask = Task { [weak self] in
            do {
                let loadedTrips = try await loadHistory.execute(vin: key.vin)
                guard !Task.isCancelled, let self, self.activeVIN == key.vin,
                      self.requestedHistoryKey == key, self.historyLoadID == operationID else { return }
                self.historyLoadTask = nil
                self.historyLoadID = nil
                self.trips = loadedTrips.sorted { $0.startedAt > $1.startedAt }
                self.hasLoadedHistory = true
                self.loadedHistoryKey = key
                self.failedHistoryKey = nil
                self.renderList()
                self.renderDetail()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, self.activeVIN == key.vin,
                      self.requestedHistoryKey == key, self.historyLoadID == operationID else { return }
                self.historyLoadTask = nil
                self.historyLoadID = nil
                self.failedHistoryKey = key
                self.loadErrorMessage = String(localized: .rideHistoryReadError)
                self.renderList()
            }
        }
    }

    func renderList() {
        guard activeVIN != nil else {
            viewState = .init(status: .bikeUnavailable, errorMessage: errorMessage)
            return
        }
        if !hasLoadedHistory, let loadErrorMessage {
            viewState = .init(status: .failed, loadErrorMessage: loadErrorMessage)
            return
        }
        guard hasLoadedHistory else {
            viewState = .init(status: .loading)
            return
        }
        viewState = mapper.mapList(
            trips: trips,
            measurementSystem: measurementSystem,
            deletingRideIDs: deletingRideIDs,
            errorMessage: errorMessage,
            loadErrorMessage: loadErrorMessage
        )
    }

    func renderDetail() {
        guard let detailTrip else { return }
        detailViewState = mapper.mapDetail(
            trip: detailTrip,
            history: trips,
            measurementSystem: measurementSystem,
            loadErrorMessage: detailLoadErrorMessage
        )
    }

    func resetHistory(for status: RideHistoryViewState.Status) {
        historyLoadTask?.cancel()
        historyLoadTask = nil
        historyLoadID = nil
        detailLoadTask?.cancel()
        detailLoadTask = nil
        detailLoadID = nil
        deleteTask?.cancel()
        deleteTask = nil
        deleteID = nil
        trips = []
        hasLoadedHistory = false
        failedHistoryKey = nil
        loadErrorMessage = nil
        detailLoadErrorMessage = nil
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
