import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeOnboarding
import RideDashboard
import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var diagnosticsViewModel: BikeDiagnosticsViewModel
    @StateObject private var batteryHealthViewModel: BatteryHealthViewModel
    @StateObject private var dashboardViewModel: RideDashboardViewModel
    @StateObject private var onboardingViewModel: BikeOnboardingViewModel
    @StateObject private var appSettingsViewModel: AppSettingsViewModel
    @StateObject private var setupFlow: BikeSetupFlowController
    @State private var path: [Route] = []
    private let lifecycleController: AppLifecycleController
    private let interfaceOrientationController: InterfaceOrientationController
    private let dashboardAccessory: () -> AnyView
    private let batteryHealthAccessory: () -> AnyView
    private let settingsAccessory: () -> AnyView

    init(
        dependencies: AppRootDependencies,
        dashboardAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) },
        batteryHealthAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) },
        settingsAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        _diagnosticsViewModel = StateObject(wrappedValue: dependencies.diagnosticsViewModel)
        _batteryHealthViewModel = StateObject(wrappedValue: dependencies.batteryHealthViewModel)
        _dashboardViewModel = StateObject(wrappedValue: dependencies.dashboardViewModel)
        _onboardingViewModel = StateObject(wrappedValue: dependencies.onboardingViewModel)
        _appSettingsViewModel = StateObject(wrappedValue: dependencies.appSettingsViewModel)
        _setupFlow = StateObject(wrappedValue: dependencies.setupFlow)
        lifecycleController = dependencies.lifecycleController
        interfaceOrientationController = dependencies.interfaceOrientationController
        self.dashboardAccessory = dashboardAccessory
        self.batteryHealthAccessory = batteryHealthAccessory
        self.settingsAccessory = settingsAccessory
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !setupFlow.isLoaded {
                    ProgressView()
                } else if setupFlow.isCompleted {
                    RideDashboardView(
                        viewModel: dashboardViewModel,
                        onDiagnostics: { path.append(.diagnostics) }
                    )
                    .overlay(alignment: .topTrailing) {
                        dashboardAccessory()
                            .padding([.top, .trailing], Constants.dashboardAccessoryPadding)
                    }
                } else {
                    BikeOnboardingView(
                        viewModel: onboardingViewModel,
                        managesObservation: false,
                        onNavigateToStep: navigateToOnboardingStep
                    )
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .onboarding(let step):
                    BikeOnboardingView(
                        viewModel: onboardingViewModel,
                        visibleStep: step,
                        managesObservation: false,
                        onNavigateToStep: navigateToOnboardingStep
                    )
                case .batteryHealth:
                    BatteryHealthView(viewModel: batteryHealthViewModel)
                        .safeAreaInset(edge: .bottom) {
                            batteryHealthAccessory()
                        }
                case .diagnostics:
                    BikeDiagnosticsView(
                        viewModel: diagnosticsViewModel,
                        onBatteryHealth: { path.append(.batteryHealth) },
                        onChangeBike: changeBike
                    )
                case .settings:
                    AppSettingsView(
                        viewModel: appSettingsViewModel,
                        onOpenTelemetry: { path.append(.diagnostics) },
                        accessory: settingsAccessory
                    )
                }
            }
        }
        .task {
            updateInterfaceOrientation()
            await lifecycleController.start()
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
        .onAppear(perform: updateInterfaceOrientation)
        .onChange(of: setupFlow.isCompleted) { _ in
            if setupFlow.isCompleted {
                path.removeAll()
            }
            lifecycleController.setIsSetupCompleted(setupFlow.isCompleted)
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
        .onChange(of: setupFlow.isLoaded) { _ in
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
        .onChange(of: path) { _ in
            updateInterfaceOrientation()
            synchronizeOnboardingBackNavigation()
        }
        .onChange(of: onboardingViewModel.viewState.step) { _ in
            navigateToCurrentOnboardingStep()
        }
        .onChange(of: scenePhase) { phase in
            lifecycleController.setCanShowLiveActivity(phase != .active)
        }
        .onDisappear {
            onboardingViewModel.stopObserving()
            lifecycleController.stop()
        }
    }

    private func changeBike() {
        lifecycleController.changeBike {
            path.removeAll()
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
    }

    private func updateInterfaceOrientation() {
        let shouldUseDashboardOrientation = setupFlow.isCompleted && path.isEmpty
        interfaceOrientationController.request(
            shouldUseDashboardOrientation ? .landscape : .portrait
        )
    }

    private func navigateToOnboardingStep(_ step: BikeOnboardingStep) {
        guard setupFlow.isLoaded, !setupFlow.isCompleted else { return }
        let route = Route.onboarding(step)
        guard path.last != route else { return }
        path.append(route)
    }

    private func synchronizeOnboardingBackNavigation() {
        guard setupFlow.isLoaded, !setupFlow.isCompleted else { return }

        let visibleStep: BikeOnboardingStep
        if case .onboarding(let step)? = path.last {
            visibleStep = step
        } else {
            visibleStep = .welcome
        }

        while onboardingViewModel.viewState.step.rawValue > visibleStep.rawValue {
            onboardingViewModel.back()
        }
    }

    private func navigateToCurrentOnboardingStep() {
        guard setupFlow.isLoaded, !setupFlow.isCompleted else { return }
        let visibleStep: BikeOnboardingStep
        if case .onboarding(let step)? = path.last {
            visibleStep = step
        } else {
            visibleStep = .welcome
        }
        let viewModelStep = onboardingViewModel.viewState.step
        guard viewModelStep.rawValue > visibleStep.rawValue else { return }
        navigateToOnboardingStep(viewModelStep)
    }

    private func synchronizeOnboardingObservation() {
        if setupFlow.isLoaded && !setupFlow.isCompleted {
            onboardingViewModel.startObserving()
        } else {
            onboardingViewModel.stopObserving()
        }
    }

    private enum Route: Hashable {
        case onboarding(BikeOnboardingStep)
        case batteryHealth
        case diagnostics
        case settings
    }

    private enum Constants {
        static let dashboardAccessoryPadding: CGFloat = 8
    }
}
