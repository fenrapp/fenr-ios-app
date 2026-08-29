import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeOnboarding
import DashboardCardSettings
import PowerModeSettings
import RideDashboard
import RideHistory
import RideNavigation
import RideNavigationDomain
import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var diagnosticsViewModel: BikeDiagnosticsViewModel
    @StateObject private var batteryHealthViewModel: BatteryHealthViewModel
    @StateObject private var onboardingViewModel: BikeOnboardingViewModel
    @StateObject private var appSettingsViewModel: AppSettingsViewModel
    @StateObject private var dashboardCardSettingsViewModel: DashboardCardSettingsViewModel
    @StateObject private var powerModeSettingsViewModel: PowerModeSettingsViewModel
    @StateObject private var rideHistoryViewModel: RideHistoryViewModel
    @StateObject private var setupFlow: BikeSetupFlowController
    @State private var path: [Route] = []
    @State private var rideNavigationPresentation: RideNavigationPresentationMode
    @State private var incomingNavigationResource: IncomingNavigationResource?
    private let lifecycleController: AppLifecycleController
    private let rideDashboardFactory: any RideDashboardFeatureBuilding
    private let interfaceOrientationController: InterfaceOrientationController
    private let rideNavigationFactory: any RideNavigationFeatureBuilding
    private let incomingMapLinkStore: any IncomingMapLinkStoring
    private let settingsAccessory: () -> AnyView

    init(
        dependencies: AppRootDependencies,
        opensRideNavigationOnLaunch: Bool = false,
        settingsAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        _diagnosticsViewModel = StateObject(wrappedValue: dependencies.diagnosticsViewModel)
        _batteryHealthViewModel = StateObject(wrappedValue: dependencies.batteryHealthViewModel)
        _onboardingViewModel = StateObject(wrappedValue: dependencies.onboardingViewModel)
        _appSettingsViewModel = StateObject(wrappedValue: dependencies.appSettingsViewModel)
        _dashboardCardSettingsViewModel = StateObject(
            wrappedValue: dependencies.dashboardCardSettingsViewModel
        )
        _powerModeSettingsViewModel = StateObject(wrappedValue: dependencies.powerModeSettingsViewModel)
        _rideHistoryViewModel = StateObject(wrappedValue: dependencies.rideHistoryViewModel)
        _setupFlow = StateObject(wrappedValue: dependencies.setupFlow)
        _rideNavigationPresentation = State(
            initialValue: opensRideNavigationOnLaunch ? .fullScreen : .hidden
        )
        lifecycleController = dependencies.lifecycleController
        rideDashboardFactory = dependencies.rideDashboardFactory
        rideNavigationFactory = dependencies.rideNavigationFactory
        incomingMapLinkStore = dependencies.incomingMapLinkStore
        interfaceOrientationController = dependencies.interfaceOrientationController
        self.settingsAccessory = settingsAccessory
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                Group {
                    if !setupFlow.isLoaded {
                        ProgressView()
                    } else if setupFlow.isCompleted {
                        RideDashboardScene(
                            factory: rideDashboardFactory,
                            onSettings: { navigateFromDashboard(to: .settings) },
                            onNavigation: showRideNavigation,
                            isNavigationActive: rideNavigationPresentation == .mini,
                            isPresentationActive: rideNavigationPresentation != .fullScreen,
                            onDiagnostics: { navigateFromDashboard(to: .diagnostics) }
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
                            onOpenDashboardCards: { path.append(.dashboardCards) },
                            onOpenPowerModes: { path.append(.powerModes) },
                            onOpenRideHistory: { path.append(.rideHistory) },
                            accessory: settingsAccessory
                        )
                    case .dashboardCards:
                        DashboardCardSettingsView(viewModel: dashboardCardSettingsViewModel)
                    case .powerModes:
                        PowerModeSettingsView(viewModel: powerModeSettingsViewModel)
                    case .rideHistory:
                        RideHistoryView(viewModel: rideHistoryViewModel)
                    }
                }
            }

            if rideNavigationPresentation != .hidden {
                RideNavigationScene(
                    factory: rideNavigationFactory,
                    presentationMode: rideNavigationPresentation,
                    importedURL: incomingNavigationResource?.url,
                    importedURLToken: incomingNavigationResource?.id,
                    onClose: hideRideNavigation,
                    onMinimize: minimizeRideNavigation,
                    onExpand: expandRideNavigation
                )
                .ignoresSafeArea()
                .zIndex(1)
            }
        }
        .onOpenURL { url in
            if url.scheme == "fenr-app", url.host == "ride-navigation" {
                expandRideNavigation()
                return
            }
            openRideNavigationResource(url)
        }
        .task {
            updateInterfaceOrientation()
            await lifecycleController.start()
            await consumeIncomingMapLink()
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
        .onAppear(perform: updateInterfaceOrientation)
        .onChange(of: setupFlow.isCompleted) {
            if setupFlow.isCompleted {
                path.removeAll()
            }
            lifecycleController.setIsSetupCompleted(setupFlow.isCompleted)
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
        .onChange(of: setupFlow.isLoaded) {
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
        .onChange(of: path) {
            updateInterfaceOrientation()
            synchronizeOnboardingBackNavigation()
        }
        .onChange(of: onboardingViewModel.viewState.step) {
            navigateToCurrentOnboardingStep()
        }
        .onChange(of: scenePhase) {
            lifecycleController.setCanShowLiveActivity(scenePhase != .active)
            if scenePhase != .active {
                lifecycleController.persistRideSession()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await consumeIncomingMapLink()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            lifecycleController.terminate()
        }
        .onDisappear {
            onboardingViewModel.stopObserving()
            lifecycleController.stop()
        }
    }
}

private extension AppRootView {
    private func changeBike() {
        lifecycleController.changeBike {
            path.removeAll()
            synchronizeOnboardingObservation()
            updateInterfaceOrientation()
        }
    }

    private func openRideNavigationResource(_ url: URL) {
        let scheme = url.scheme?.lowercased()
        let isSupported = url.pathExtension.lowercased() == "gpx"
            || url.pathExtension.lowercased() == "directionsrequest"
            || scheme == "https"
        guard isSupported else { return }
        incomingNavigationResource = IncomingNavigationResource(url: url)
        expandRideNavigation()
    }

    private func consumeIncomingMapLink() async {
        guard let link = try? await incomingMapLinkStore.consume() else { return }
        openRideNavigationResource(link.url)
    }

    private func updateInterfaceOrientation() {
        let shouldUseDashboardOrientation = rideNavigationPresentation != .hidden
            || (setupFlow.isCompleted && path.isEmpty)
        interfaceOrientationController.request(
            shouldUseDashboardOrientation ? .landscape : .portrait
        )
    }

    private func showRideNavigation() {
        expandRideNavigation()
    }

    private func minimizeRideNavigation() {
        withAnimation(navigationTransitionAnimation) {
            rideNavigationPresentation = .mini
        }
        updateInterfaceOrientation()
    }

    private func expandRideNavigation() {
        withAnimation(navigationTransitionAnimation) {
            rideNavigationPresentation = .fullScreen
        }
        updateInterfaceOrientation()
    }

    private func hideRideNavigation() {
        withAnimation(navigationTransitionAnimation) {
            rideNavigationPresentation = .hidden
        }
        incomingNavigationResource = nil
        updateInterfaceOrientation()
    }

    private var navigationTransitionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: Constants.reducedNavigationTransitionDuration)
            : .smooth(duration: Constants.navigationTransitionDuration)
    }

    private func navigateFromDashboard(to route: Route) {
        guard rideNavigationPresentation != .mini else {
            expandRideNavigation()
            return
        }
        path.append(route)
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
        case dashboardCards
        case powerModes
        case rideHistory
    }

    private struct IncomingNavigationResource: Equatable {
        let id = UUID()
        let url: URL
    }

    private enum Constants {
        static let navigationTransitionDuration = 0.35
        static let reducedNavigationTransitionDuration = 0.12
    }
}
