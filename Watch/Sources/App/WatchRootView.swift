import AppSettings
import SwiftUI
import WatchDashboard
import WatchOnboarding

struct WatchRootView: View {
    @State private var dashboardViewModel: WatchDashboardViewModel
    @State private var onboardingViewModel: WatchOnboardingViewModel
    @State private var settingsViewModel: AppSettingsViewModel
    @State private var setupController: WatchSetupController
    @State private var navigationCoordinator: WatchNavigationCoordinator

    init(dependencies: WatchRootDependencies) {
        _dashboardViewModel = State(initialValue: dependencies.dashboardViewModel)
        _settingsViewModel = State(initialValue: dependencies.settingsViewModel)
        _onboardingViewModel = State(initialValue: dependencies.onboardingViewModel)
        _setupController = State(initialValue: dependencies.setupController)
        _navigationCoordinator = State(initialValue: dependencies.navigationCoordinator)
    }

    var body: some View {
        NavigationStack(path: pathBinding) {
            rootContent
                .navigationDestination(for: WatchRoute.self) { route in
                    destination(route)
                }
        }
        .task {
            await setupController.start()
            synchronizeSetup()
        }
        .onChange(of: setupController.isLoading) { synchronizeSetup() }
        .onChange(of: setupController.isConfigured) { synchronizeSetup() }
    }
}

private extension WatchRootView {
    var pathBinding: Binding<[WatchRoute]> {
        Binding(
            get: { navigationCoordinator.state.path },
            set: { navigationCoordinator.send(.replacePath($0)) }
        )
    }

    @ViewBuilder
    var rootContent: some View {
        switch navigationCoordinator.state.root {
        case .loading:
            ProgressView()
        case .dashboard:
            WatchDashboardView(
                viewModel: dashboardViewModel,
                onNavigation: handleDashboardEvent
            )
        case .onboarding:
            WatchOnboardingView(viewModel: onboardingViewModel)
        }
    }

    @ViewBuilder
    func destination(_ route: WatchRoute) -> some View {
        switch route {
        case .settings:
            AppSettingsScene(
                destination: .overview,
                viewModel: settingsViewModel,
                isPresentationActive: navigationCoordinator.state.path.last == .settings,
                onNavigation: { _ in }
            )
        }
    }

    func handleDashboardEvent(_ event: WatchDashboardNavigationEvent) {
        switch event {
        case .changeBike:
            navigationCoordinator.send(.resetSetup)
            setupController.changeBike()
        case .openSettings:
            if let intent = WatchNavigationEventAdapter.intent(for: event) {
                navigationCoordinator.send(intent)
            }
        }
    }

    func synchronizeSetup() {
        let root: WatchNavigationRoot
        if setupController.isLoading {
            root = .loading
        } else {
            root = setupController.isConfigured ? .dashboard : .onboarding
        }
        navigationCoordinator.send(.setRoot(root))
    }
}
