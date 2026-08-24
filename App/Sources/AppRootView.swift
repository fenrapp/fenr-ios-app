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
                    BikeOnboardingView(viewModel: onboardingViewModel)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
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
            await setupFlow.load()
            bikeLiveActivityController.start()
            bikeLiveActivityController.setIsSetupCompleted(setupFlow.isCompleted)
            if let vin = setupFlow.configuredVIN {
                await sessionController.start()
                await sessionController.connectAutomatically(vin: vin)
            }
            updateInterfaceOrientation()
        }
        .onAppear(perform: updateInterfaceOrientation)
        .onChange(of: setupFlow.isCompleted) { _ in
            bikeLiveActivityController.setIsSetupCompleted(setupFlow.isCompleted)
            updateInterfaceOrientation()
        }
        .onChange(of: path) { _ in
            updateInterfaceOrientation()
        }
        .onChange(of: scenePhase) { phase in
            bikeLiveActivityController.setCanShowLiveActivity(phase != .active)
        }
        .onDisappear {
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
        }
    }

    private func updateInterfaceOrientation() {
        let shouldUseDashboardOrientation = setupFlow.isCompleted && path.isEmpty
        InterfaceOrientationController.shared.request(
            shouldUseDashboardOrientation ? .landscape : .portrait
        )
    }

    private enum Route: Hashable {
        case batteryHealth
        case diagnostics
        case settings
    }
}
