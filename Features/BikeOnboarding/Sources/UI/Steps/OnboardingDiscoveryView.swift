import SwiftUI

struct OnboardingDiscoveryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let viewState: BikeOnboardingViewState
    let onSelectBike: (BikeDiscoveryViewData) -> Void
    let onRetry: () -> Void

    @State private var rowsVisible = false

    var body: some View {
        OnboardingStepLayout(
            eyebrow: BikeOnboardingL10n.text(.bikeOnboardingDiscoveryEyebrow),
            title: title,
            detail: detail
        ) {
            VStack(spacing: Constants.contentSpacing) {
                if showsDiscoveryCluster {
                    discoveryCluster
                } else {
                    statusView
                }
                bikesContent
            }
        } footer: {
            if showsRecovery {
                OnboardingPrimaryButton(
                    title: BikeOnboardingL10n.text(.bikeOnboardingActionScanAgain),
                    systemImage: "arrow.clockwise",
                    action: onRetry
                )
            }
        }
        .id(viewState.discoveryState)
        .transition(.opacity)
        .animation(recoveryAnimation, value: viewState.discoveryState)
        .task(id: animationIdentity) {
            rowsVisible = reduceMotion
            guard !viewState.discoveredBikes.isEmpty, !reduceMotion else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            rowsVisible = true
        }
    }

    private var discoveryCluster: some View {
        VStack(spacing: Constants.clusterSpacing) {
            OnboardingDiscoveryRadarView(isScanning: viewState.isDiscoveringBikes)
                .accessibilityHidden(true)
            VStack(spacing: Constants.progressSpacing) {
                Text(discoveryClusterTitle)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                if viewState.discoveryState == .stabilizing, !reduceMotion {
                    OnboardingStabilizationProgressView()
                        .frame(maxWidth: Constants.progressMaxWidth)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(discoveryAccessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private var statusView: some View {
        Group {
            switch viewState.discoveryState {
            case .scanning:
                EmptyView()
            case .stabilizing:
                EmptyView()
            case .multiple:
                Text(.bikeOnboardingDiscoveryNearbyCount(viewState.discoveredBikes.count))
                    .font(.subheadline.weight(.semibold))
            case .timedOut:
                EmptyView()
            case .paused, .failed:
                Text(.bikeOnboardingDiscoveryPaused)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var showsDiscoveryCluster: Bool {
        viewState.discoveryState == .scanning
            || viewState.discoveryState == .stabilizing
    }

    private var discoveryClusterTitle: String {
        switch viewState.discoveryState {
        case .stabilizing:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryConfirming)
        default:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryScanningNearby)
        }
    }

    private var discoveryAccessibilityLabel: String {
        switch viewState.discoveryState {
        case .stabilizing:
            BikeOnboardingL10n.text(.bikeOnboardingAccessibilityDiscoveryConfirming)
        default:
            BikeOnboardingL10n.text(.bikeOnboardingAccessibilityDiscoveryScanning)
        }
    }

    @ViewBuilder private var bikesContent: some View {
        if viewState.discoveryState == .stabilizing, let bike = viewState.discoveredBikes.first {
            OnboardingDiscoveredBikeRow(bike: bike, isSelectable: false, onSelect: {})
                .opacity(rowsVisible ? 1 : .zero)
                .scaleEffect(rowsVisible ? 1 : Constants.rowEntranceScale)
                .animation(rowAnimation(delay: .zero), value: rowsVisible)
        } else if viewState.discoveryState == .multiple {
            VStack(spacing: Constants.rowSpacing) {
                ForEach(Array(viewState.discoveredBikes.enumerated()), id: \.element.id) { index, bike in
                    OnboardingDiscoveredBikeRow(
                        bike: bike,
                        isSelectable: true,
                        onSelect: { onSelectBike(bike) }
                    )
                    .opacity(rowsVisible ? 1 : .zero)
                    .scaleEffect(rowsVisible ? 1 : Constants.rowEntranceScale)
                    .animation(rowAnimation(delay: Double(index) * Constants.rowEntranceDelay), value: rowsVisible)
                }
            }
        }
    }

    private var title: String {
        switch viewState.discoveryState {
        case .scanning:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryScanningTitle)
        case .stabilizing:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryStabilizingTitle)
        case .multiple:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryMultipleTitle)
        case .timedOut:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryTimedOutTitle)
        case .paused, .failed:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryFailedTitle)
        }
    }

    private var detail: String {
        switch viewState.discoveryState {
        case .scanning:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryScanningDetail)
        case .stabilizing:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryStabilizingDetail)
        case .multiple:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryMultipleDetail)
        case .timedOut:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryTimedOutDetail)
        case .paused, .failed:
            BikeOnboardingL10n.text(.bikeOnboardingDiscoveryFailedDetail)
        }
    }

    private var showsRecovery: Bool {
        viewState.discoveryState == .timedOut
            || viewState.discoveryState == .paused
            || viewState.discoveryState == .failed
    }

    private var animationIdentity: String {
        "\(viewState.discoveryState)-\(viewState.discoveredBikes.map(\.vin).joined())"
    }

    private func rowAnimation(delay: TimeInterval) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeOut(duration: Constants.rowEntranceDuration).delay(delay)
    }

    private var recoveryAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: Constants.recoveryTransitionDuration)
    }
}

private struct OnboardingStabilizationProgressView: View {
    @State private var progress = 0.0

    var body: some View {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .accessibilityHidden(true)
            .onAppear {
                progress = .zero
                withAnimation(.linear(duration: Constants.duration)) {
                    progress = 1
                }
            }
    }

    private enum Constants {
        static let duration = 2.0
    }
}

private extension OnboardingDiscoveryView {
    enum Constants {
        static let contentSpacing: CGFloat = 18
        static let clusterSpacing: CGFloat = 14
        static let progressSpacing: CGFloat = 10
        static let progressMaxWidth: CGFloat = 220
        static let rowSpacing: CGFloat = 10
        static let rowEntranceScale = 0.98
        static let rowEntranceDuration = 0.25
        static let rowEntranceDelay = 0.05
        static let recoveryTransitionDuration = 0.2
    }
}
