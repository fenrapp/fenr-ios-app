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
            NavigationStack(path: $router.path) {
                Group {
                    if !setupFlow.isLoaded {
                        ProgressView()
                    } else if setupFlow.isCompleted {
                        RideDashboardScene(
                            factory: rideDashboardFactory,
                            onSettings: {
                                router.navigate(to: .settings, reduceMotion: reduceMotion)
                            },
                            onNavigation: { router.showRideNavigation(reduceMotion: reduceMotion) },
                            isNavigationActive: router.rideNavigationPresentation == .mini,
                            isPresentationActive: router.isDashboardPresentationActive,
                            onDiagnostics: {
                                router.navigate(to: .diagnostics, reduceMotion: reduceMotion)
                            }
                        )
                    } else {
                        BikeOnboardingView(
                            viewModel: onboardingViewModel,
                            managesObservation: false,
                            onNavigateToStep: router.navigateToOnboardingStep
                        )
                    }
                }
                .navigationDestination(for: AppRootRouter.Route.self) { route in
                    switch route {
                    case .onboarding(let step):
                        BikeOnboardingView(
                            viewModel: onboardingViewModel,
                            visibleStep: step,
                            managesObservation: false,
                            onNavigateToStep: router.navigateToOnboardingStep
                        )
                    case .batteryHealth:
                        BatteryHealthView(viewModel: batteryHealthViewModel)
                    case .diagnostics:
                        BikeDiagnosticsView(
                            viewModel: diagnosticsViewModel,
                            onBatteryHealth: {
                                router.navigate(to: .batteryHealth, reduceMotion: reduceMotion)
                            },
                            onChangeBike: changeBike
                        )
                    case .settings:
                        AppSettingsView(
                            viewModel: appSettingsViewModel,
                            onOpenTelemetry: {
                                router.navigate(to: .diagnostics, reduceMotion: reduceMotion)
                            },
                            onOpenDashboardCards: {
                                router.navigate(to: .dashboardCards, reduceMotion: reduceMotion)
                            },
                            onOpenPowerModes: {
                                router.navigate(to: .powerModes, reduceMotion: reduceMotion)
                            },
                            onOpenRideHistory: {
                                router.navigate(to: .rideHistory, reduceMotion: reduceMotion)
                            },
                            bikeLockModeTitle: bikeLockSettingsViewModel.viewState.isAvailable
                                ? bikeLockSettingsViewModel.viewState.currentModeTitle
                                : nil,
                            onOpenBikeLock: {
                                router.navigate(to: .bikeLockSettings, reduceMotion: reduceMotion)
                            },
                            accessory: settingsAccessory
                        )
                    case .bikeLockSettings:
                        BikeLockSettingsView(viewModel: bikeLockSettingsViewModel)
                    case .dashboardCards:
                        DashboardCardSettingsView(viewModel: dashboardCardSettingsViewModel)
                    case .powerModes:
                        PowerModeSettingsView(viewModel: powerModeSettingsViewModel)
                    case .rideHistory:
                        RideHistoryView(viewModel: rideHistoryViewModel)
                    }
                }
            }

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
            router.rootPresentationDidStart()
            await lifecycleController.start()
            await router.consumeIncomingMapLink(reduceMotion: reduceMotion)
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
        }
        .onChange(of: onboardingViewModel.viewState.step) {
            router.onboardingStepDidChange()
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
            router.rootPresentationDidStop()
            bikeLockSettingsViewModel.stop()
            lifecycleController.stop()
        }
    }
}

private extension AppRootView {
    func changeBike() {
        lifecycleController.changeBike {
            router.changeBikeDidComplete()
        }
    }
}
