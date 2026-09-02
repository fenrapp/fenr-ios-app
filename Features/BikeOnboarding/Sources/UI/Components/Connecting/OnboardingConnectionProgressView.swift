import SwiftUI

struct OnboardingConnectionProgressView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let phase: BikeOnboardingConnectionPhase

    @State private var activeIndicatorVisible = true
    @State private var haloExpanded = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalProgress
            } else {
                horizontalProgress
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.bikeOnboardingAccessibilityConnectionProgress)
        .accessibilityValue(BikeOnboardingL10n.progressAccessibility(
            title: title(for: phase),
            step: phase.rawValue + 1,
            count: phases.count
        ))
        .accessibilityAddTraits(.updatesFrequently)
        .task(id: animationIdentity) { await animateCurrentPhase() }
    }

    private var horizontalProgress: some View {
        HStack(spacing: Constants.horizontalSpacing) {
            ForEach(Array(phases.enumerated()), id: \.element.rawValue) { index, item in
                horizontalNode(item)
                if index < phases.count - 1 {
                    connector(isComplete: index < phase.rawValue)
                }
            }
        }
    }

    private var verticalProgress: some View {
        VStack(alignment: .leading, spacing: .zero) {
            ForEach(Array(phases.enumerated()), id: \.element.rawValue) { index, item in
                HStack(spacing: Constants.verticalContentSpacing) {
                    VStack(spacing: .zero) {
                        indicator(for: item)
                        if index < phases.count - 1 {
                            connector(isComplete: index < phase.rawValue)
                                .frame(width: Constants.verticalLineWidth, height: Constants.verticalLineHeight)
                        }
                    }
                    Text(title(for: item))
                        .font(.body.weight(item == phase ? .semibold : .regular))
                        .foregroundStyle(item.rawValue <= phase.rawValue ? .primary : .secondary)
                        .padding(.bottom, index < phases.count - 1 ? Constants.verticalLineHeight : .zero)
                }
            }
        }
    }

    private func horizontalNode(_ item: BikeOnboardingConnectionPhase) -> some View {
        VStack(spacing: Constants.nodeSpacing) {
            indicator(for: item)
            Text(title(for: item))
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.rawValue <= phase.rawValue ? .primary : .secondary)
        }
    }

    private func indicator(for item: BikeOnboardingConnectionPhase) -> some View {
        ZStack {
            if item == phase, !reduceMotion {
                Circle()
                    .stroke(Color.primary.opacity(Constants.haloOpacity), lineWidth: Constants.haloWidth)
                    .frame(width: Constants.indicatorSize, height: Constants.indicatorSize)
                    .scaleEffect(haloExpanded ? Constants.haloScale : 1)
                    .opacity(haloExpanded ? .zero : 1)
            }

            Circle()
                .fill(indicatorFill(for: item))
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(borderOpacity(for: item)), lineWidth: Constants.borderWidth)
                }
                .frame(width: Constants.indicatorSize, height: Constants.indicatorSize)

            if item.rawValue < phase.rawValue {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(Color(uiColor: .systemBackground))
            } else if item == phase {
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: Constants.activeDotSize, height: Constants.activeDotSize)
            }
        }
        .opacity(item == phase && !activeIndicatorVisible ? .zero : 1)
        .scaleEffect(item == phase && !activeIndicatorVisible ? Constants.activeStartScale : 1)
        .accessibilityHidden(true)
    }

    private func connector(isComplete: Bool) -> some View {
        Capsule()
            .fill(isComplete ? Color.primary : Color.primary.opacity(Constants.inactiveOpacity))
            .frame(maxWidth: .infinity)
            .frame(height: Constants.horizontalLineHeight)
            .animation(reduceMotion ? nil : .easeInOut(duration: Constants.railDuration), value: isComplete)
            .accessibilityHidden(true)
    }

    private func indicatorFill(for item: BikeOnboardingConnectionPhase) -> Color {
        item.rawValue <= phase.rawValue ? .primary : Color.primary.opacity(Constants.inactiveOpacity)
    }

    private func borderOpacity(for item: BikeOnboardingConnectionPhase) -> Double {
        item.rawValue <= phase.rawValue ? .zero : Constants.upcomingBorderOpacity
    }

    private var phases: [BikeOnboardingConnectionPhase] {
        BikeOnboardingConnectionPhase.allCases
    }

    private var animationIdentity: String {
        "\(phase.rawValue)-\(reduceMotion)"
    }

    @MainActor
    private func animateCurrentPhase() async {
        if reduceMotion {
            activeIndicatorVisible = true
            haloExpanded = false
            return
        }

        activeIndicatorVisible = false
        haloExpanded = false
        await Task.yield()
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: Constants.indicatorDuration)) {
            activeIndicatorVisible = true
        }
        withAnimation(.easeInOut(duration: Constants.haloDuration).repeatForever(autoreverses: false)) {
            haloExpanded = true
        }
    }

    private func title(for phase: BikeOnboardingConnectionPhase) -> String {
        switch phase {
        case .finding: BikeOnboardingL10n.text(.bikeOnboardingProgressFinding)
        case .securing: BikeOnboardingL10n.text(.bikeOnboardingProgressSecuring)
        case .live: BikeOnboardingL10n.text(.bikeOnboardingProgressLive)
        }
    }
}

private extension OnboardingConnectionProgressView {
    enum Constants {
        static let horizontalSpacing: CGFloat = 10
        static let verticalContentSpacing: CGFloat = 14
        static let nodeSpacing: CGFloat = 8
        static let indicatorSize: CGFloat = 30
        static let activeDotSize: CGFloat = 8
        static let activeStartScale = 0.96
        static let horizontalLineHeight: CGFloat = 3
        static let verticalLineWidth: CGFloat = 3
        static let verticalLineHeight: CGFloat = 44
        static let borderWidth: CGFloat = 1
        static let inactiveOpacity = 0.12
        static let upcomingBorderOpacity = 0.18
        static let haloOpacity = 0.18
        static let haloWidth: CGFloat = 2
        static let haloScale = 1.7
        static let railDuration = 0.3
        static let indicatorDuration = 0.22
        static let haloDuration = 1.3
    }
}
