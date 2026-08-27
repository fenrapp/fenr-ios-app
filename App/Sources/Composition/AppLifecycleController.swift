import RideSession
import VehicleSession

@MainActor
final class AppLifecycleController {
    private let sessionController: BikeSessionController
    private let setupFlow: BikeSetupFlowController
    private let bikeLiveActivityController: BikeLiveActivityController
    private let rideSession: any RideSessionService
    private let vehicleSession: any VehicleSessionService
    private var changeBikeTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        sessionController: BikeSessionController,
        setupFlow: BikeSetupFlowController,
        bikeLiveActivityController: BikeLiveActivityController,
        rideSession: any RideSessionService,
        vehicleSession: any VehicleSessionService
    ) {
        self.sessionController = sessionController
        self.setupFlow = setupFlow
        self.bikeLiveActivityController = bikeLiveActivityController
        self.rideSession = rideSession
        self.vehicleSession = vehicleSession
    }

    deinit {
        changeBikeTask?.cancel()
        persistenceTask?.cancel()
        // Shutdown deliberately owns its dependencies and may outlive the composition root.
    }

    func start() async {
        guard !hasStarted, stopTask == nil else { return }
        hasStarted = true
        await vehicleSession.start()
        guard !Task.isCancelled else { return }
        await rideSession.start()
        guard !Task.isCancelled else { return }
        await setupFlow.load()
        guard !Task.isCancelled else { return }
        bikeLiveActivityController.start()
        bikeLiveActivityController.setIsSetupCompleted(setupFlow.isCompleted)
        guard let vin = setupFlow.configuredVIN else { return }
        await sessionController.start()
        guard !Task.isCancelled else { return }
        await sessionController.connectAutomatically(vin: vin)
    }

    func stop() {
        guard stopTask == nil else { return }
        changeBikeTask?.cancel()
        let pendingChangeBike = changeBikeTask
        let pendingPersistence = persistenceTask
        stopTask = Task { [sessionController, bikeLiveActivityController, rideSession, vehicleSession] in
            await pendingChangeBike?.value
            await pendingPersistence?.value
            await bikeLiveActivityController.stop()
            await rideSession.completeCurrentTrip()
            await rideSession.flush()
            await rideSession.stop()
            await vehicleSession.stop()
            await sessionController.stop()
        }
    }

    func persistRideSession() {
        guard stopTask == nil else { return }
        let precedingPersistence = persistenceTask
        persistenceTask = Task { [rideSession] in
            await precedingPersistence?.value
            guard !Task.isCancelled else { return }
            await rideSession.persistCurrentTrip()
        }
    }

    func terminate() {
        stop()
    }

    func setCanShowLiveActivity(_ canShow: Bool) {
        bikeLiveActivityController.setCanShowLiveActivity(canShow)
    }

    func setIsSetupCompleted(_ isCompleted: Bool) {
        bikeLiveActivityController.setIsSetupCompleted(isCompleted)
    }

    func changeBike(onCompleted: @escaping @MainActor () -> Void) {
        guard changeBikeTask == nil, stopTask == nil else { return }
        let sessionController = sessionController
        let setupFlow = setupFlow
        let bikeLiveActivityController = bikeLiveActivityController
        let rideSession = rideSession
        let pendingPersistence = persistenceTask
        changeBikeTask = Task { [weak self] in
            defer { self?.changeBikeTask = nil }
            await pendingPersistence?.value
            guard !Task.isCancelled else { return }
            await rideSession.completeCurrentTrip()
            await rideSession.flush()
            await sessionController.disconnect()
            guard !Task.isCancelled else { return }
            await setupFlow.reset()
            guard !Task.isCancelled else { return }
            bikeLiveActivityController.setIsSetupCompleted(false)
            onCompleted()
        }
    }
}
