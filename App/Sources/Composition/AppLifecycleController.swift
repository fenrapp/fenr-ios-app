import BLETraceDomain
import RideSession
import VehicleSession

@MainActor
final class AppLifecycleController {
    private enum State {
        case stopped
        case starting
        case started
        case stopping
    }

    private let sessionController: BikeSessionController
    private let setupFlow: BikeSetupFlowController
    private let bikeLiveActivityController: BikeLiveActivityController
    private let rideSession: any RideSessionService
    private let vehicleSession: any VehicleSessionService
    private let bleTraceStoragePreparer: any BLETraceStoragePreparing
    private let startupPreparer: any AppStartupPreparing
    private var changeBikeTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var state = State.stopped
    private var didStartVehicleSession = false
    private var didStartRideSession = false
    private var didStartLiveActivity = false
    private var didStartBikeRepository = false

    init(
        sessionController: BikeSessionController,
        setupFlow: BikeSetupFlowController,
        bikeLiveActivityController: BikeLiveActivityController,
        rideSession: any RideSessionService,
        vehicleSession: any VehicleSessionService,
        bleTraceStoragePreparer: any BLETraceStoragePreparing,
        startupPreparer: any AppStartupPreparing
    ) {
        self.sessionController = sessionController
        self.setupFlow = setupFlow
        self.bikeLiveActivityController = bikeLiveActivityController
        self.rideSession = rideSession
        self.vehicleSession = vehicleSession
        self.bleTraceStoragePreparer = bleTraceStoragePreparer
        self.startupPreparer = startupPreparer
    }

    deinit {
        changeBikeTask?.cancel()
        persistenceTask?.cancel()
        startTask?.cancel()
        // Shutdown deliberately owns its dependencies and may outlive the composition root.
    }

    func start() async {
        switch state {
        case .started:
            return
        case .starting:
            await startTask?.value
            return
        case .stopping:
            await stopTask?.value
            await start()
        case .stopped:
            state = .starting
            let task = Task { [weak self] in
                guard let self else { return }
                await self.performStart()
            }
            startTask = task
            await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
            if task.isCancelled {
                stop()
            }
        }
    }

    func stop() {
        guard state != .stopped, state != .stopping else { return }
        state = .stopping
        changeBikeTask?.cancel()
        startTask?.cancel()
        let pendingStart = startTask
        let pendingChangeBike = changeBikeTask
        let pendingPersistence = persistenceTask
        stopTask = Task { [weak self] in
            guard let self else { return }
            await pendingStart?.value
            await pendingChangeBike?.value
            await pendingPersistence?.value
            if didStartLiveActivity {
                await bikeLiveActivityController.stop()
            }
            if didStartRideSession {
                await rideSession.stop()
            }
            if didStartVehicleSession {
                await vehicleSession.stop()
            }
            if didStartBikeRepository {
                await sessionController.stop()
            }
            didStartLiveActivity = false
            didStartRideSession = false
            didStartVehicleSession = false
            didStartBikeRepository = false
            changeBikeTask = nil
            persistenceTask = nil
            startTask = nil
            stopTask = nil
            state = .stopped
        }
    }

    func stopAndWait() async {
        stop()
        await stopTask?.value
        await sessionController.stopIncludingOnboarding()
        await bikeLiveActivityController.endForExperienceChange()
    }

    func persistRideSession() {
        guard state == .started else { return }
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

    func retryConnection() {
        guard state == .started,
              changeBikeTask == nil,
              let vin = setupFlow.configuredVIN
        else {
            return
        }
        sessionController.retryConnection(vin: vin)
    }

    func changeBike(onCompleted: @escaping @MainActor () -> Void) {
        guard state == .started, changeBikeTask == nil else { return }
        let sessionController = sessionController
        let setupFlow = setupFlow
        let bikeLiveActivityController = bikeLiveActivityController
        let rideSession = rideSession
        let pendingPersistence = persistenceTask
        changeBikeTask = Task { [weak self] in
            defer { self?.changeBikeTask = nil }
            await pendingPersistence?.value
            guard !Task.isCancelled else { return }
            await rideSession.stop()
            guard !Task.isCancelled else { return }
            await sessionController.disconnect()
            guard !Task.isCancelled else { return }
            await setupFlow.reset()
            guard !Task.isCancelled else { return }
            await rideSession.start()
            guard !Task.isCancelled else { return }
            bikeLiveActivityController.setIsSetupCompleted(false)
            onCompleted()
        }
    }
}

private extension AppLifecycleController {
    func performStart() async {
        await startupPreparer.prepare()
        guard canContinueStarting else { return }

        await vehicleSession.start()
        didStartVehicleSession = true
        guard canContinueStarting else { return }

        await rideSession.start()
        didStartRideSession = true
        guard canContinueStarting else { return }

        await setupFlow.load()
        guard canContinueStarting else { return }

        bikeLiveActivityController.start()
        didStartLiveActivity = true
        bikeLiveActivityController.setIsSetupCompleted(setupFlow.isCompleted)
        guard let vin = setupFlow.configuredVIN, canContinueStarting else {
            completeStartWithoutRepository()
            return
        }

        await bleTraceStoragePreparer.prepareStorage()
        guard canContinueStarting else { return }

        await sessionController.start()
        didStartBikeRepository = true
        guard canContinueStarting else { return }

        await sessionController.connectAutomatically(vin: vin)
        guard canContinueStarting else { return }
        startTask = nil
        state = .started
    }

    var canContinueStarting: Bool {
        state == .starting && !Task.isCancelled
    }

    func completeStartWithoutRepository() {
        guard canContinueStarting else { return }
        startTask = nil
        state = .started
    }
}
