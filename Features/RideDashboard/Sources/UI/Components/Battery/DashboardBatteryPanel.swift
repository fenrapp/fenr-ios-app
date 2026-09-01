import DesignSystem
import SwiftUI

struct DashboardBatteryPanel: View {
    let state: RideDashboardViewState.Battery
    let showsEstimatedRange: Bool
    let estimatedRange: DashboardRangeViewData.Summary?

    @State private var showsRangeExplanation = false

    init(
        state: RideDashboardViewState.Battery,
        showsEstimatedRange: Bool = false,
        estimatedRange: DashboardRangeViewData.Summary? = nil
    ) {
        self.state = state
        self.showsEstimatedRange = showsEstimatedRange
        self.estimatedRange = estimatedRange
    }

    var body: some View {
        Group {
            if showsEstimatedRange, let estimatedRange {
                Button {
                    showsRangeExplanation = true
                } label: {
                    estimatedRangeIndicator(estimatedRange)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows how the estimate is calculated")
            } else {
                percentageIndicator
            }
        }
        .alert("Estimated range", isPresented: $showsRangeExplanation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(Constants.rangeExplanation)
        }
    }

    private var percentageIndicator: some View {
        indicator(accessibilityLabel: state.accessibilityLabel, width: Constants.percentageWidth) {
            indicatorIcon(systemName: "bolt.fill")

            Text(percentageText)
                .font(.system(size: Constants.valueFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumTextScale)
        }
    }

    private func estimatedRangeIndicator(_ range: DashboardRangeViewData.Summary) -> some View {
        indicator(accessibilityLabel: range.accessibilityLabel) {
            indicatorIcon(systemName: "road.lanes")

            rangeText(range)
        }
    }

    private func rangeText(_ range: DashboardRangeViewData.Summary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.rangeValueSpacing) {
            Text(range.valueText)
                .font(.system(size: Constants.valueFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()

            Text(range.unitText)
                .font(.system(size: Constants.rangeUnitFontSize, weight: .semibold, design: .rounded))
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func indicator<Content: View>(
        accessibilityLabel: String,
        width: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: DesignSpace.extraSmall) {
            content()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Constants.contentHorizontalPadding)
        .frame(minWidth: Constants.minimumWidth)
        .frame(width: width, height: Constants.height)
        .background {
            Capsule()
                .fill(tint.opacity(Constants.backgroundOpacity))
        }
        .overlay {
            Capsule()
                .stroke(tint, lineWidth: Constants.outlineWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func indicatorIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: Constants.iconFontSize, weight: .semibold))
            .accessibilityHidden(true)
    }

    private var percentageText: String {
        guard state.percentageText.hasSuffix("%") else { return state.percentageText }
        return String(state.percentageText.dropLast())
    }

    private var tint: Color {
        switch state.emphasis {
        case .unavailable: DesignColor.secondaryText
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let percentageWidth: CGFloat = 112
        static let minimumWidth: CGFloat = 112
        static let height: CGFloat = 60
        static let outlineWidth: CGFloat = 2.75
        static let backgroundOpacity = 0.08
        static let iconFontSize: CGFloat = 22
        static let valueFontSize: CGFloat = 26
        static let rangeUnitFontSize: CGFloat = 15
        static let rangeValueSpacing: CGFloat = 2
        static let contentHorizontalPadding: CGFloat = 10
        static let minimumTextScale: CGFloat = 0.72
        static let rangeExplanation = "Calculated from the remaining battery energy, recent consumption, "
            + "and eligible saved trips for this bike. Riding style, terrain, temperature, and conditions "
            + "can change the actual range."
    }
}
