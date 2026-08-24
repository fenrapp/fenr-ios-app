import DesignSystem
import SwiftUI
import UIKit

public struct BikeOnboardingView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var viewModel: BikeOnboardingViewModel
    @State private var isScannerPresented = false
    @State private var isScannerUnavailable = false
    private let visibleStep: BikeOnboardingStep
    private let managesObservation: Bool
    private let onNavigateToStep: @MainActor (BikeOnboardingStep) -> Void

    public init(
        viewModel: BikeOnboardingViewModel,
        visibleStep: BikeOnboardingStep = .welcome,
        managesObservation: Bool = true,
        onNavigateToStep: @escaping @MainActor (BikeOnboardingStep) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.visibleStep = visibleStep
        self.managesObservation = managesObservation
        self.onNavigateToStep = onNavigateToStep
    }

    public var body: some View {
        onboardingScreen(for: visibleStep)
        .task {
            guard managesObservation else { return }
            viewModel.startObserving()
        }
        .onDisappear {
            guard managesObservation else { return }
            viewModel.stopObserving()
        }
    }

    private func onboardingScreen(for step: BikeOnboardingStep) -> some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                ScrollView {
                    stepContent(for: step)
                        .frame(maxWidth: Constants.contentMaxWidth)
                        .padding(.horizontal, DesignSpace.large)
                        .padding(.top, DesignSpace.large)
                        .padding(.bottom, DesignSpace.large)
                        .frame(maxWidth: .infinity)
                }

                controls(for: step)
                    .padding(.horizontal, DesignSpace.large)
                    .padding(.bottom, DesignSpace.extraSmall)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(.medium ... .accessibility2)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .sheet(isPresented: $isScannerPresented) { scannerSheet }
        .alert("Scanner unavailable", isPresented: $isScannerUnavailable) {
            Button("Use Manual Entry", role: .cancel) {}
        } message: {
            Text("Enter the 17-character VIN manually to continue.")
        }
    }

    @ViewBuilder
    private func stepContent(for step: BikeOnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeOnboardingStepView()
        case .preparation:
            PrepareBikeOnboardingStepView(
                viewState: viewModel.viewState,
                onOpenSettings: openAppSettings
            )
        case .identify:
            IdentifyBikeOnboardingStepView(
                viewState: viewModel.viewState,
                onVINChange: viewModel.vinChanged,
                onSelectBike: viewModel.selectDiscoveredBike,
                onStartDiscovery: viewModel.startDiscovery,
                onScanVIN: { isScannerPresented = true }
            )
        case .connect:
            ConnectBikeOnboardingStepView(
                viewState: viewModel.viewState,
                onOpenSettings: openAppSettings,
                onRetry: viewModel.retry
            )
        }
    }

    private func controls(for step: BikeOnboardingStep) -> some View {
        OnboardingNavigationControls(
            step: step,
            isContinueDisabled: !viewModel.viewState.canContinue,
            isContinueBusy: viewModel.viewState.isRequestingBluetoothAccess,
            onContinue: { continueTapped(from: step) }
        )
        .frame(maxWidth: Constants.contentMaxWidth)
    }

    private var scannerSheet: some View {
        VINScannerView(onVIN: { vin in
            viewModel.vinChanged(vin)
            isScannerPresented = false
        }, onUnavailable: {
            isScannerPresented = false
            isScannerUnavailable = true
        })
        .ignoresSafeArea()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func continueTapped(from visibleStep: BikeOnboardingStep) {
        viewModel.next()
        let nextStep = viewModel.viewState.step
        guard nextStep.rawValue > visibleStep.rawValue else { return }
        onNavigateToStep(nextStep)
    }

    private enum Constants {
        static let contentMaxWidth: CGFloat = 480
    }
}
