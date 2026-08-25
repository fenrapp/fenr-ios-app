import Foundation

@MainActor
final class AppLifecycleController {
    private let sessionController: BikeSessionController
    private let setupFlow: BikeSetupFlowController
    private let bikeLiveActivityController: BikeLiveActivityController
    private var changeBikeTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?

    init(
        sessionController: BikeSessionController,
        setupFlow: BikeSetupFlowController,
        bikeLiveActivityController: BikeLiveActivityController
    ) {
        self.sessionController = sessionController
        self.setupFlow = setupFlow
        self.bikeLiveActivityController = bikeLiveActivityController
    }

    deinit {
        changeBikeTask?.cancel()
        stopTask?.cancel()
    }

    func start() async {
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
        bikeLiveActivityController.stop()
        stopTask?.cancel()
        stopTask = Task { [sessionController] in
            await sessionController.stop()
        }
    }

    func setCanShowLiveActivity(_ canShow: Bool) {
        bikeLiveActivityController.setCanShowLiveActivity(canShow)
    }

    func setIsSetupCompleted(_ isCompleted: Bool) {
        bikeLiveActivityController.setIsSetupCompleted(isCompleted)
    }

    func changeBike(onCompleted: @escaping @MainActor () -> Void) {
        guard changeBikeTask == nil else { return }
        let sessionController = sessionController
        let setupFlow = setupFlow
        let bikeLiveActivityController = bikeLiveActivityController
        changeBikeTask = Task { [weak self] in
            defer { self?.changeBikeTask = nil }
            await sessionController.disconnect()
            guard !Task.isCancelled else { return }
            await setupFlow.reset()
            guard !Task.isCancelled else { return }
            bikeLiveActivityController.setIsSetupCompleted(false)
            onCompleted()
        }
    }
}
