import Combine
import Foundation
import RideSession
import VehicleSession

@MainActor
public final class RideDynamicsCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardRideDynamicsViewData()

    private let rideSession: any RideSessionService
    private let vehicleSession: any VehicleSessionService
    private let mapper: RideDynamicsCardMapper
    private let locationConsumerID = UUID()
    private var observationTask: Task<Void, Never>?
    private var locationRequestTask: Task<Void, Never>?
    private var calibrationTask: Task<Void, Never>?
    private var isVisible = false
    private var isRequestingLocation = false

    public init(
        rideSession: any RideSessionService,
        vehicleSession: any VehicleSessionService,
        mapper: RideDynamicsCardMapper
    ) {
        self.rideSession = rideSession
        self.vehicleSession = vehicleSession
        self.mapper = mapper
    }

    deinit {
        observationTask?.cancel()
        calibrationTask?.cancel()
        guard isRequestingLocation else { return }
        let previousRequest = locationRequestTask
        let vehicleSession = vehicleSession
        let consumerID = locationConsumerID
        Task {
            await previousRequest?.value
            await vehicleSession.setLocationMonitoringRequired(false, consumerID: consumerID)
        }
    }

    func setIsVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else { return }
        self.isVisible = isVisible
        if isVisible {
            observeIfNeeded()
            setLocationRequired(true)
        } else {
            observationTask?.cancel()
            observationTask = nil
            setLocationRequired(false)
        }
    }

    func calibrate() {
        guard calibrationTask == nil else { return }
        let vehicleSession = vehicleSession
        calibrationTask = Task { [weak self] in
            await vehicleSession.zeroBikeAttitude()
            guard !Task.isCancelled else { return }
            self?.calibrationTask = nil
        }
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardRideDynamicsViewData) {
        self.viewState = viewState
    }
#endif
}

private extension RideDynamicsCardViewModel {
    func observeIfNeeded() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self, rideSession] in
            let stream = await rideSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    func receive(_ snapshot: RideSessionSnapshot) {
        guard isVisible else { return }
        let next = mapper.map(snapshot)
        guard next != viewState else { return }
        viewState = next
    }

    func setLocationRequired(_ required: Bool) {
        guard required != isRequestingLocation else { return }
        isRequestingLocation = required
        let previousRequest = locationRequestTask
        let vehicleSession = vehicleSession
        let consumerID = locationConsumerID
        locationRequestTask = Task {
            await previousRequest?.value
            guard !Task.isCancelled else { return }
            await vehicleSession.setLocationMonitoringRequired(required, consumerID: consumerID)
        }
    }
}
