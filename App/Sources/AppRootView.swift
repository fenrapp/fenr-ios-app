import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var featureStore: AppFeatureStore
    @StateObject private var setupFlow: BikeSetupFlowController
    @StateObject private var navigationCoordinator: AppNavigationCoordinator
    private let incomingMapLinkController: IncomingMapLinkController
    private let presentationController: AppPresentationController
    private let lifecycleController: AppLifecycleController
    private let externalNavigationResolver: AppExternalNavigationResolver
    private let settingsAccessory: () -> AnyView

    init(
        dependencies: AppRootDependencies,
        settingsAccessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        _featureStore = StateObject(wrappedValue: dependencies.featureStore)
        _setupFlow = StateObject(wrappedValue: dependencies.setupFlow)
        _navigationCoordinator = StateObject(wrappedValue: dependencies.navigationCoordinator)
        incomingMapLinkController = dependencies.incomingMapLinkController
        presentationController = dependencies.presentationController
        lifecycleController = dependencies.lifecycleController
        externalNavigationResolver = dependencies.externalNavigationResolver
        self.settingsAccessory = settingsAccessory
    }

    var body: some View {
        ZStack {
            rootContent
            AppRideNavigationHost(
                coordinator: navigationCoordinator,
                featureStore: featureStore
            )
        }
        .onOpenURL(perform: openExternalURL)
        .task { await start() }
        .onAppear { synchronizePresentation() }
        .onChange(of: setupFlow.isCompleted) { setupDidChange() }
        .onChange(of: setupFlow.isLoaded) { setupDidChange() }
        .onChange(of: navigationCoordinator.state) { synchronizePresentation() }
        .onChange(of: scenePhase) { updateScenePhase() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await incomingMapLinkController.consume()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            lifecycleController.terminate()
        }
        .onDisappear(perform: stop)
    }
}

private extension AppRootView {
    @ViewBuilder
    var rootContent: some View {
        switch navigationCoordinator.state.root {
        case .loading:
            ProgressView()
        case .onboarding:
            AppOnboardingHost(featureStore: featureStore)
        case .dashboard:
            AppMainNavigationHost(
                coordinator: navigationCoordinator,
                featureStore: featureStore,
                settingsAccessory: settingsAccessory,
                onRetryConnection: lifecycleController.retryConnection,
                onChangeBike: changeBike
            )
        }
    }

    func start() async {
        await lifecycleController.start()
        guard !Task.isCancelled else { return }
        setupDidChange()
        await incomingMapLinkController.consume()
        guard !Task.isCancelled else { return }
        featureStore.bikeLockSettingsViewModel.start()
    }

    func stop() {
        featureStore.diagnosticsViewModel.setPresentationActive(false)
        featureStore.batteryHealthViewModel.setPresentationActive(false)
        featureStore.appSettingsViewModel.stop()
        featureStore.dashboardCardSettingsViewModel.stop()
        featureStore.powerModeSettingsViewModel.stop()
        featureStore.rideHistoryViewModel.stop()
        featureStore.bikeLockSettingsViewModel.stop()
        incomingMapLinkController.cancel()
        lifecycleController.stop()
    }

    func setupDidChange() {
        lifecycleController.setIsSetupCompleted(setupFlow.isCompleted)
        let root: AppNavigationRoot
        if !setupFlow.isLoaded {
            root = .loading
        } else {
            root = setupFlow.isCompleted ? .dashboard : .onboarding
        }
        navigationCoordinator.send(.setRoot(root))
    }

    func synchronizePresentation() {
        presentationController.update(for: navigationCoordinator.state)
    }

    func updateScenePhase() {
        lifecycleController.setCanShowLiveActivity(scenePhase != .active)
        if scenePhase != .active {
            lifecycleController.persistRideSession()
        }
    }

    func openExternalURL(_ url: URL) {
        guard let request = externalNavigationResolver.resolve(url) else { return }
        navigationCoordinator.open(request)
    }

    func changeBike() {
        lifecycleController.changeBike {
            navigationCoordinator.send(.resetSetup)
        }
    }
}
