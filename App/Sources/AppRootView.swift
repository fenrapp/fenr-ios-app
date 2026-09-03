import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeLockSettings
import BikeOnboarding
import DashboardCardSettings
import PowerModeSettings
import RideDashboard
import RideHistory
import RideNavigation
import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var diagnosticsViewModel: BikeDiagnosticsViewModel
    @StateObject private var batteryHealthViewModel: BatteryHealthViewModel
    @StateObject private var bikeLockSettingsViewModel: BikeLockSettingsViewModel
    @StateObject private var onboardingViewModel: BikeOnboardingViewModel
    @StateObject private var appSettingsViewModel: AppSettingsViewModel
    @StateObject private var dashboardCardSettingsViewModel: DashboardCardSettingsViewModel
    @StateObject private var powerModeSettingsViewModel: PowerModeSettingsViewModel
    @StateObject private var rideHistoryViewModel: RideHistoryViewModel
    @StateObject private var setupFlow: BikeSetupFlowController
    @StateObject private var router: AppRootRouter
    private let lifecycleController: AppLifecycleController
    private let rideDashboardFactory: any RideDashboardFeatureBuilding
    private let rideNavigationFactory: any RideNavigationFeatureBuilding
    private let settingsAccessory: () -> AnyView

    init(
        dependencies: AppRootDependencies,
        settingsAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        _diagnosticsViewModel = StateObject(wrappedValue: dependencies.diagnosticsViewModel)
        _batteryHealthViewModel = StateObject(wrappedValue: dependencies.batteryHealthViewModel)
        _bikeLockSettingsViewModel = StateObject(wrappedValue: dependencies.bikeLockSettingsViewModel)
        _onboardingViewModel = StateObject(wrappedValue: dependencies.onboardingViewModel)
        _appSettingsViewModel = StateObject(wrappedValue: dependencies.appSettingsViewModel)
        _dashboardCardSettingsViewModel = StateObject(
            wrappedValue: dependencies.dashboardCardSettingsViewModel
        )
        _powerModeSettingsViewModel = StateObject(wrappedValue: dependencies.powerModeSettingsViewModel)
        _rideHistoryViewModel = StateObject(wrappedValue: dependencies.rideHistoryViewModel)
        _setupFlow = StateObject(wrappedValue: dependencies.setupFlow)
        _router = StateObject(wrappedValue: dependencies.router)
        lifecycleController = dependencies.lifecycleController
        rideDashboardFactory = dependencies.rideDashboardFactory
        rideNavigationFactory = dependencies.rideNavigationFactory
        self.settingsAccessory = settingsAccessory
    }

    var body: some View {
        ZStack {
            rootContent

            if router.rideNavigationPresentation != .hidden {
                RideNavigationScene(
                    factory: rideNavigationFactory,
                    presentationMode: router.rideNavigationPresentation,
                    importedURL: router.incomingNavigationResource?.url,
                    importedURLToken: router.incomingNavigationResource?.id,
                    onClose: { router.hideRideNavigation(reduceMotion: reduceMotion) },
                    onMinimize: { router.minimizeRideNavigation(reduceMotion: reduceMotion) },
                    onExpand: { router.expandRideNavigation(reduceMotion: reduceMotion) }
                )
                .zIndex(1)
            }
        }
        .onOpenURL { url in
            router.open(url, reduceMotion: reduceMotion)
        }
        .task {
            await lifecycleController.start()
            guard !Task.isCancelled else { return }
            synchronizeAdvancedDataPresentation()
            await router.consumeIncomingMapLink(reduceMotion: reduceMotion)
            guard !Task.isCancelled else { return }
            bikeLockSettingsViewModel.start()
        }
        .onAppear(perform: router.rootPresentationDidStart)
        .onChange(of: setupFlow.isCompleted) {
            lifecycleController.setIsSetupCompleted(setupFlow.isCompleted)
            router.setupStateDidChange()
        }
        .onChange(of: setupFlow.isLoaded) {
            router.setupStateDidChange()
        }
        .onChange(of: router.path) {
            router.pathDidChange()
            synchronizeAdvancedDataPresentation()
        }
        .onChange(of: scenePhase) {
            lifecycleController.setCanShowLiveActivity(scenePhase != .active)
            if scenePhase != .active {
                lifecycleController.persistRideSession()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await router.consumeIncomingMapLink(reduceMotion: reduceMotion)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            lifecycleController.terminate()
        }
        .onDisappear {
            stopAdvancedDataPresentation()
            bikeLockSettingsViewModel.stop()
            lifecycleController.stop()
        }
    }
}

private extension AppRootView {
    @ViewBuilder var rootContent: some View {
        if !setupFlow.isLoaded {
            ProgressView()
        } else if setupFlow.isCompleted {
            appNavigationStack
        } else {
            BikeOnboardingView(viewModel: onboardingViewModel)
        }
    }

    var appNavigationStack: some View {
        NavigationStack(path: $router.path) {
            RideDashboardScene(
                factory: rideDashboardFactory,
                onSettings: {
                    router.navigate(to: .settings, reduceMotion: reduceMotion)
                },
                onNavigation: { router.showRideNavigation(reduceMotion: reduceMotion) },
                isNavigationActive: router.rideNavigationPresentation == .mini,
                isPresentationActive: router.isDashboardPresentationActive,
                onDiagnostics: {
                    router.navigate(to: .diagnostics(.overview), reduceMotion: reduceMotion)
                }
            )
            .navigationDestination(for: AppRootRouter.Route.self) { route in
                appDestination(route)
            }
        }
    }

    @ViewBuilder func appDestination(_ route: AppRootRouter.Route) -> some View {
        switch route {
        case .batteryHealth(let destination):
            BatteryHealthScene(
                destination: destination,
                viewModel: batteryHealthViewModel,
                onNavigate: { destination in
                    router.navigate(to: .batteryHealth(destination), reduceMotion: reduceMotion)
                }
            )
        case .diagnostics(let destination):
            BikeDiagnosticsScene(
                destination: destination,
                viewModel: diagnosticsViewModel,
                onNavigate: { destination in
                    router.navigate(to: .diagnostics(destination), reduceMotion: reduceMotion)
                },
                onBatteryHealth: {
                    router.navigate(to: .batteryHealth(.overview), reduceMotion: reduceMotion)
                },
                onChangeBike: changeBike
            )
        case .settings:
            appSettingsDestination
        case .rideDisplaySettings:
            RideDisplaySettingsView(viewModel: appSettingsViewModel)
        case .bikeLockSettings:
            BikeLockSettingsView(viewModel: bikeLockSettingsViewModel)
        case .dashboardCards:
            DashboardCardSettingsView(viewModel: dashboardCardSettingsViewModel)
        case .powerModes:
            PowerModeSettingsView(viewModel: powerModeSettingsViewModel)
        case .bikeModelSettings:
            BikeModelSettingsView(viewModel: appSettingsViewModel)
        case .rideHistory:
            RideHistoryView(viewModel: rideHistoryViewModel)
        }
    }

    var appSettingsDestination: some View {
        AppSettingsView(
            viewModel: appSettingsViewModel,
            onOpenTelemetry: { navigate(to: .diagnostics(.overview)) },
            onOpenRideDisplay: { navigate(to: .rideDisplaySettings) },
            onOpenDashboardCards: { navigate(to: .dashboardCards) },
            onOpenPowerModes: { navigate(to: .powerModes) },
            onOpenBikeModel: { navigate(to: .bikeModelSettings) },
            onOpenRideHistory: { navigate(to: .rideHistory) },
            bikeLockModeTitle: bikeLockSettingsViewModel.viewState.isAvailable
                ? bikeLockSettingsViewModel.viewState.currentModeTitle
                : nil,
            onOpenBikeLock: { navigate(to: .bikeLockSettings) },
            accessory: settingsAccessory
        )
    }

    func navigate(to route: AppRootRouter.Route) {
        router.navigate(to: route, reduceMotion: reduceMotion)
    }

    func changeBike() {
        lifecycleController.changeBike {
            router.changeBikeDidComplete()
        }
    }

    func synchronizeAdvancedDataPresentation() {
        diagnosticsViewModel.setPresentationActive(router.isDiagnosticsPresentationActive)
        batteryHealthViewModel.setPresentationActive(router.isBatteryHealthPresentationActive)
    }

    func stopAdvancedDataPresentation() {
        diagnosticsViewModel.setPresentationActive(false)
        batteryHealthViewModel.setPresentationActive(false)
    }
}
