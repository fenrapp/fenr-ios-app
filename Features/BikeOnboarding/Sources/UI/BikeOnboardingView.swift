import DesignSystem
import SwiftUI

public struct BikeOnboardingView: View {
    @ObservedObject private var viewModel: BikeOnboardingViewModel
    @State private var isScannerPresented = false
    @State private var isScannerUnavailable = false

    public init(viewModel: BikeOnboardingViewModel) { self.viewModel = viewModel }

    public var body: some View {
        VStack(spacing: DesignSpace.large) {
            OnboardingProgressView(currentStep: viewModel.viewState.step)
            Spacer(minLength: DesignSpace.extraSmall)
            stepContent
                .frame(maxWidth: Constants.contentMaxWidth)
            Spacer(minLength: DesignSpace.extraSmall)
            controls
        }
        .padding(DesignSpace.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColor.groupedSurface)
        .dynamicTypeSize(.medium ... .accessibility2)
        .task { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
        .sheet(isPresented: $isScannerPresented) { scannerSheet }
        .alert("Scanner unavailable", isPresented: $isScannerUnavailable) {
            Button("Use Manual Entry", role: .cancel) {}
        } message: {
            Text("Enter the 17-character VIN manually to continue.")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch viewModel.viewState.step {
            case .welcome:
                OnboardingStepCard(icon: "gauge.with.dots.needle.67percent", title: "Your Stark dashboard") {
                    Text("FENR connects to your bike to display live telemetry, battery health, and diagnostics.")
                    Text("It does not change bike settings.")
                }
            case .preparation:
                OnboardingStepCard(icon: "bluetooth", title: "Prepare your bike") {
                    Text("Turn on the bike, keep it nearby, and allow Bluetooth access when iOS asks.")
                }
            case .identify:
                OnboardingStepCard(icon: "number", title: "Add your VIN") {
                    OnboardingIdentifyBikeView(
                        vin: viewModel.viewState.vin,
                        discoveredBikes: viewModel.viewState.discoveredBikes,
                        isDiscoveringBikes: viewModel.viewState.isDiscoveringBikes,
                        onVINChange: viewModel.vinChanged,
                        onSelectBike: viewModel.selectDiscoveredBike,
                        onStartDiscovery: viewModel.startDiscovery,
                        onScanVIN: { isScannerPresented = true }
                    )
                }
            case .connect:
                OnboardingStepCard(icon: "antenna.radiowaves.left.and.right", title: "Connect your bike") {
                    ProgressView().opacity(viewModel.viewState.isConnecting ? 1 : 0)
                    Text(viewModel.viewState.connectionDetail).foregroundStyle(.secondary)
                    if let errorMessage = viewModel.viewState.errorMessage {
                        Text(errorMessage).foregroundStyle(DesignColor.critical)
                        Button("Try Again") { viewModel.retry() }.buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var controls: some View {
        OnboardingNavigationControls(
            step: viewModel.viewState.step,
            onBack: viewModel.back,
            onContinue: viewModel.next
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

    private enum Constants {
        static let contentMaxWidth: CGFloat = 480
    }
}

#if DEBUG
#Preview("Onboarding welcome") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(state: .init())
    )
}

#Preview("Onboarding identify") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .identify, vin: "FENRTEST000000001")
        )
    )
}

#Preview("Onboarding connection failure") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .connect,
                vin: "FENRTEST000000001",
                connectionDetail: "Bluetooth unavailable",
                errorMessage: "Turn on Bluetooth and try again."
            )
        )
    )
}
#endif
