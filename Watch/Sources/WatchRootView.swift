import BikeDomain
import SwiftUI
import WatchDashboard

struct WatchRootView: View {
    @StateObject private var sessionController: WatchBikeSessionController
    @StateObject private var dashboardViewModel: WatchDashboardViewModel
    @StateObject private var onboardingViewModel: WatchOnboardingViewModel
    private let profileRepository: any BikeProfileRepository
    private let initialProfile: BikeProfile?
    @StateObject private var setup: WatchSetupState

    init(container: WatchAppDependencyContainer) {
        let sessionController = WatchBikeSessionController(repository: container.repository)
        let setup = WatchSetupState()
        _sessionController = StateObject(wrappedValue: sessionController)
        _dashboardViewModel = StateObject(wrappedValue: container.makeDashboardViewModel())
        _onboardingViewModel = StateObject(wrappedValue: container.makeOnboardingViewModel { profile in
            setup.profile = profile
        })
        _setup = StateObject(wrappedValue: setup)
        profileRepository = container.profileRepository
        initialProfile = container.initialProfile
    }

    var body: some View {
        NavigationStack {
            Group {
                if setup.isLoading {
                    ProgressView()
                } else if setup.profile != nil {
                    WatchDashboardView(viewModel: dashboardViewModel, onChangeBike: changeBike)
                } else {
                    WatchOnboardingView(viewModel: onboardingViewModel)
                }
            }
        }
        .task {
            await sessionController.start()
            let loadedProfile = initialProfile ?? await profileRepository.loadProfile()
            setup.profile = loadedProfile
            setup.isLoading = false
            if let loadedProfile {
                await sessionController.connectAutomatically(vin: loadedProfile.vin)
            }
        }
        .onDisappear { Task { await sessionController.stop() } }
    }

    private func changeBike() {
        Task {
            await sessionController.disconnect()
            await profileRepository.clearProfile()
            setup.profile = nil
        }
    }
}

@MainActor
private final class WatchSetupState: ObservableObject {
    @Published var profile: BikeProfile?
    @Published var isLoading = true
}
