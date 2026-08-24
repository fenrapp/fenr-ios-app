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
    @StateObject private var chargingDashboardViewModel: ChargingDashboardViewModel
    @StateObject private var onboardingViewModel: BikeOnboardingViewModel
    @StateObject private var appSettingsViewModel: AppSettingsViewModel
    @StateObject private var sessionController: BikeSessionController
    @StateObject private var setupFlow: BikeSetupFlowController
    @State private var path: [Route] = []
    private let bikeLiveActivityController: BikeLiveActivityController
    private let batteryHealthAccessory: () -> AnyView

    init(
        container: AppDependencyContainer,
        batteryHealthAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        let session = container.makeBikeSession()
        let setupFlow = BikeSetupFlowController(
            useCases: container.makeBikeProfileUseCases(),
            forceOnboarding: container.forceOnboarding
        )
        _diagnosticsViewModel = StateObject(wrappedValue: container.makeBikeDiagnosticsViewModel(session: session))
        _batteryHealthViewModel = StateObject(
            wrappedValue: container.makeBatteryHealthViewModel(session: session)
        )
        _dashboardViewModel = StateObject(
            wrappedValue: container.makeRideDashboardViewModel(session: session)
        )
        _chargingDashboardViewModel = StateObject(
            wrappedValue: container.makeChargingDashboardViewModel(session: session)
        )
        _sessionController = StateObject(wrappedValue: BikeSessionController(repository: session.repository))
        _setupFlow = StateObject(wrappedValue: setupFlow)
        bikeLiveActivityController = container.makeBikeLiveActivityController(session: session)
        _onboardingViewModel = StateObject(
            wrappedValue: container.makeOnboardingViewModel { vin in
                setupFlow.complete(vin: vin)
            }
        )
        _appSettingsViewModel = StateObject(wrappedValue: container.makeAppSettingsViewModel())
        self.batteryHealthAccessory = batteryHealthAccessory
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !setupFlow.isLoaded {
                    ProgressView()
                } else if setupFlow.isCompleted {
                    RideDashboardView(
                        viewModel: dashboardViewModel,
                        chargingViewModel: chargingDashboardViewModel,
                        onDiagnostics: { path.append(.diagnostics) },
                        onSettings: { path.append(.settings) }
                    )
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
                        onOpenTelemetry: { path.append(.diagnostics) }
                    )
                }
            }
        }
        .task {
            updateInterfaceOrientation()
            await setupFlow.load()
            bikeLiveActivityController.start()
            bikeLiveActivityController.setIsSetupCompleted(setupFlow.isCompleted)
            if let vin = setupFlow.configuredVIN {
                await sessionController.start()
                await sessionController.connectAutomatically(vin: vin)
            }
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
        .onAppear(perform: updateInterfaceOrientation)
        .onChange(of: setupFlow.isCompleted) { _ in
            bikeLiveActivityController.setIsSetupCompleted(setupFlow.isCompleted)
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
            bikeLiveActivityController.setCanShowLiveActivity(phase != .active)
        }
        .onDisappear {
            onboardingViewModel.stopObserving()
            bikeLiveActivityController.stop()
            Task { await sessionController.stop() }
        }
    }

    private func changeBike() {
        Task {
            await sessionController.disconnect()
            await setupFlow.reset()
            bikeLiveActivityController.setIsSetupCompleted(false)
            path.removeAll()
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
    }

    private func updateInterfaceOrientation() {
        let shouldUseDashboardOrientation = setupFlow.isCompleted && path.isEmpty
        InterfaceOrientationController.shared.request(
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
}
