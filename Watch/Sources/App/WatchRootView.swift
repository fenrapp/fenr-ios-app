import AppSettings
import SwiftUI
import WatchDashboard
import WatchOnboarding

struct WatchRootView: View {
    @StateObject private var dashboardViewModel: WatchDashboardViewModel
    @StateObject private var onboardingViewModel: WatchOnboardingViewModel
    @StateObject private var settingsViewModel: AppSettingsViewModel
    @StateObject private var setupController: WatchSetupController
    @State private var isPresentingSettings = false
    init(dependencies: WatchRootDependencies) {
        _dashboardViewModel = StateObject(wrappedValue: dependencies.dashboardViewModel)
        _settingsViewModel = StateObject(wrappedValue: dependencies.settingsViewModel)
        _onboardingViewModel = StateObject(wrappedValue: dependencies.onboardingViewModel)
        _setupController = StateObject(wrappedValue: dependencies.setupController)
    }

    var body: some View {
        NavigationStack {
            Group {
                if setupController.isLoading {
                    ProgressView()
                } else if setupController.isConfigured {
                    WatchDashboardView(
                        viewModel: dashboardViewModel,
                        onChangeBike: setupController.changeBike,
                        onOpenSettings: { isPresentingSettings = true }
                    )
                } else {
                    WatchOnboardingView(viewModel: onboardingViewModel)
                }
            }
            .navigationDestination(isPresented: $isPresentingSettings) {
                AppSettingsView(viewModel: settingsViewModel)
            }
        }
        .task {
            await setupController.start()
        }
    }
}
