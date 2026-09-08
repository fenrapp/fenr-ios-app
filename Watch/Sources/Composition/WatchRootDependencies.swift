import AppSettings
import BikeDomain
import Observation
import WatchDashboard
import WatchOnboarding

@MainActor
struct WatchRootDependencies {
    let dashboardViewModel: WatchDashboardViewModel
    let onboardingViewModel: WatchOnboardingViewModel
    let settingsViewModel: AppSettingsViewModel
    let setupController: WatchSetupController
    let navigationCoordinator: WatchNavigationCoordinator
}

@MainActor
@Observable
final class WatchSetupController {
    private(set) var isConfigured = false
    private(set) var isLoading = true

    private let sessionController: WatchBikeSessionController
    private let profileRepository: any BikeProfileRepository
    private let initialProfile: BikeProfile?
    @ObservationIgnored private var changeBikeTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false

    init(
        sessionController: WatchBikeSessionController,
        profileRepository: any BikeProfileRepository,
        initialProfile: BikeProfile?
    ) {
        self.sessionController = sessionController
        self.profileRepository = profileRepository
        self.initialProfile = initialProfile
    }

    deinit {
        changeBikeTask?.cancel()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await sessionController.start()
        guard !Task.isCancelled else {
            hasStarted = false
            return
        }
        let loadedProfile = if let initialProfile {
            initialProfile
        } else {
            await profileRepository.loadProfile()
        }
        guard !Task.isCancelled else {
            hasStarted = false
            return
        }
        isConfigured = loadedProfile != nil
        isLoading = false
        if let loadedProfile {
            await sessionController.connectAutomatically(vin: loadedProfile.vin)
        }
    }

    func complete() {
        isConfigured = true
    }

    func changeBike() {
        guard changeBikeTask == nil else { return }
        let sessionController = sessionController
        let profileRepository = profileRepository
        changeBikeTask = Task { [weak self] in
            defer { self?.changeBikeTask = nil }
            await sessionController.disconnect()
            guard !Task.isCancelled else { return }
            await profileRepository.clearProfile()
            guard !Task.isCancelled else { return }
            self?.isConfigured = false
        }
    }
}
