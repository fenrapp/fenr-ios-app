import SwiftUI

struct IdentifyBikeOnboardingStepView: View {
    let viewState: BikeOnboardingViewState
    let onVINChange: (String) -> Void
    let onSelectBike: (BikeDiscoveryViewData) -> Void
    let onStartDiscovery: () -> Void
    let onScanVIN: () -> Void

    var body: some View {
        OnboardingStepCard(
            icon: "number",
            title: "Identify your bike",
            subtitle: "Choose a nearby bike or enter the 17-character VIN manually."
        ) {
            OnboardingIdentifyBikeView(
                vin: viewState.vin,
                discoveredBikes: viewState.discoveredBikes,
                isDiscoveringBikes: viewState.isDiscoveringBikes,
                onVINChange: onVINChange,
                onSelectBike: onSelectBike,
                onStartDiscovery: onStartDiscovery,
                onScanVIN: onScanVIN
            )
        }
    }
}
