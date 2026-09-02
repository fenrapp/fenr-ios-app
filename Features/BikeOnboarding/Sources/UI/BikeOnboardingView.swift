import SwiftUI
import UIKit

public struct BikeOnboardingView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @ObservedObject private var viewModel: BikeOnboardingViewModel
    @State private var navigationPath: [BikeOnboardingRoute] = []
    @State private var navigationSynchronizationTask: Task<Void, Never>?

    public init(viewModel: BikeOnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            onboardingScene { rootContent }
            .navigationDestination(for: BikeOnboardingRoute.self) { route in
                switch route {
                case .setup:
                    onboardingScene { setupContent }
                case .detail:
                    onboardingScene { detailContent }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .foregroundStyle(.primary)
        .tint(.primary)
        .task {
            viewModel.setVoiceOverEnabled(voiceOverEnabled)
            viewModel.startObserving()
        }
        .onChange(of: voiceOverEnabled) { _, isEnabled in
            viewModel.setVoiceOverEnabled(isEnabled)
        }
        .onChange(of: viewModel.viewState.step, initial: true) { _, _ in
            scheduleNavigationSynchronization()
        }
        .onChange(of: navigationPath) { _, path in
            handleNavigationChange(path)
        }
        .onDisappear {
            navigationSynchronizationTask?.cancel()
            navigationSynchronizationTask = nil
            viewModel.stopObserving()
        }
        .sensoryFeedback(.success, trigger: viewModel.viewState.step) { _, currentStep in
            currentStep == .success
        }
    }

    @ViewBuilder private var rootContent: some View {
        if viewModel.viewState.step == .success {
            OnboardingSuccessView(
                requiresExplicitContinue: voiceOverEnabled,
                onContinue: viewModel.continueFromSuccess
            )
        } else {
            OnboardingHeroView(onContinue: viewModel.getStarted)
        }
    }

    @ViewBuilder private var setupContent: some View {
        switch viewModel.viewState.step {
        case .bluetooth:
            OnboardingBluetoothView(
                viewState: viewModel.viewState,
                onContinue: viewModel.continueBluetooth,
                onOpenSettings: openAppSettings
            )
        case .discovery:
            OnboardingDiscoveryView(
                viewState: viewModel.viewState,
                onSelectBike: viewModel.selectDiscoveredBike,
                onRetry: viewModel.retryDiscovery
            )
        default:
            OnboardingDiscoveryView(
                viewState: viewModel.viewState,
                onSelectBike: viewModel.selectDiscoveredBike,
                onRetry: viewModel.retryDiscovery
            )
        }
    }

    @ViewBuilder private var detailContent: some View {
        switch viewModel.viewState.step {
        case .pairing:
            OnboardingPairingView(
                viewState: viewModel.viewState,
                onCopyAndPair: viewModel.copyAndPair
            )
        case .connecting:
            OnboardingConnectingView(
                viewState: viewModel.viewState,
                onRetry: viewModel.retryConnection,
                onCancel: viewModel.cancelConnection
            )
        default:
            EmptyView()
        }
    }

    private func onboardingScene<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            OnboardingObsidianBackground()
            content()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private var desiredNavigationPath: [BikeOnboardingRoute] {
        switch viewModel.viewState.step {
        case .welcome, .success:
            []
        case .bluetooth, .discovery:
            [.setup]
        case .pairing, .connecting:
            [.setup, .detail]
        }
    }

    private func synchronizeNavigation() {
        let desiredPath = desiredNavigationPath
        guard navigationPath != desiredPath else { return }
        navigationPath = desiredPath
    }

    private func scheduleNavigationSynchronization() {
        navigationSynchronizationTask?.cancel()
        navigationSynchronizationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            synchronizeNavigation()
        }
    }

    private func handleNavigationChange(_ path: [BikeOnboardingRoute]) {
        guard path != desiredNavigationPath else { return }
        if path.count < desiredNavigationPath.count {
            viewModel.back()
        } else {
            synchronizeNavigation()
        }
    }
}

private enum BikeOnboardingRoute: Hashable {
    case setup
    case detail
}
