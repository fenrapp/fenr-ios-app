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
    private var observationTask: Task<Void, Never>?
    private var isVisible = false

    public init(
        rideSession: any RideSessionService,
        vehicleSession: any VehicleSessionService,
        mapper: RideDynamicsCardMapper
    ) {
        self.rideSession = rideSession
        self.vehicleSession = vehicleSession
        self.mapper = mapper
    }

    deinit { observationTask?.cancel() }

    func setIsVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        if isVisible {
            observeIfNeeded()
        } else {
            observationTask?.cancel()
            observationTask = nil
        }
    }

    func calibrate() {
        Task { [vehicleSession] in await vehicleSession.calibrateDeviceMotion() }
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
}
