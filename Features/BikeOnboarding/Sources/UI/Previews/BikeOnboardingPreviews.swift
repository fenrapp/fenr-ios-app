import BikeDomain
import DesignSystem
import SwiftUI

#if DEBUG
#Preview("Onboarding welcome") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(state: .init())
    )
}

#Preview("Onboarding preparation") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(state: .init(step: .preparation)),
        visibleStep: .preparation
    )
}

#Preview("Onboarding requesting Bluetooth") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .preparation,
                isRequestingBluetoothAccess: true
            )
        ),
        visibleStep: .preparation
    )
}

#Preview("Onboarding Bluetooth denied") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .preparation,
                showsBluetoothSettingsButton: true,
                errorMessage: "Allow Bluetooth access in Settings > FENR, then return to continue."
            )
        ),
        visibleStep: .preparation
    )
}

#Preview("Onboarding identify") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .identify,
                vin: "FENRTEST000000001",
                discoveredBikes: [
                    .init(vin: "FENRTEST000000001", rssi: -45),
                    .init(vin: "FENRTEST000000002", rssi: -64)
                ]
            )
        ),
        visibleStep: .identify
    )
}

#Preview("Onboarding connecting") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .connect,
                vin: "FENRTEST000000001",
                connectionDetail: "Authenticating",
                connectionPhase: .authenticating,
                isConnecting: true
            )
        ),
        visibleStep: .connect
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
        ),
        visibleStep: .connect
    )
}

#Preview("Onboarding components") {
    VStack(spacing: DesignSpace.medium) {
        OnboardingProgressView(currentStep: .identify)
        OnboardingMaterialPanel {
            OnboardingFeatureRow(
                icon: "power",
                title: "Bike nearby",
                detail: "Turn it on and keep it close to your iPhone."
            )
        }
        ConnectionTimelineView(currentPhase: .discovering)
    }
    .padding()
    .background(OnboardingBackground())
}
#endif
