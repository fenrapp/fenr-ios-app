import DesignSystem
import SettingsDomain
import SwiftUI

struct DashboardBatteryPanel: View {
    let state: RideDashboardViewState.Battery
    let displayMode: DashboardBatteryIndicatorMode
    let estimatedRange: DashboardRangeViewData.Summary?

    @State private var showsRangeExplanation = false

    init(
        state: RideDashboardViewState.Battery,
        displayMode: DashboardBatteryIndicatorMode = .percentage,
        estimatedRange: DashboardRangeViewData.Summary? = nil
    ) {
        self.state = state
        self.displayMode = displayMode
        self.estimatedRange = estimatedRange
    }

    var body: some View {
        Group {
            switch displayMode {
            case .percentage:
                indicator(
                    text: percentageText,
                    systemImage: "bolt.fill",
                    accessibilityLabel: state.accessibilityLabel
                )
            case .estimatedRange:
                if let estimatedRange {
                    Button {
                        showsRangeExplanation = true
                    } label: {
                        indicator(
                            text: estimatedRange.text,
                            systemImage: "road.lanes",
                            accessibilityLabel: estimatedRange.accessibilityLabel
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows how the estimate is calculated")
                } else {
                    indicator(
                        text: percentageText,
                        systemImage: "bolt.fill",
                        accessibilityLabel: state.accessibilityLabel
                    )
                }
            }
        }
        .alert("Estimated range", isPresented: $showsRangeExplanation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(Constants.rangeExplanation)
        }
    }

    private func indicator(
        text: String,
        systemImage: String,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: DesignSpace.extraSmall) {
            Image(systemName: systemImage)
                .font(.system(size: Constants.iconFontSize, weight: .semibold))
                .accessibilityHidden(true)

            Text(text)
                .font(.system(size: Constants.percentageFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumTextScale)
        }
        .foregroundStyle(tint)
        .frame(width: Constants.width, height: Constants.height)
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
        static let width: CGFloat = 112
        static let height: CGFloat = 60
        static let outlineWidth: CGFloat = 2.75
        static let backgroundOpacity = 0.08
        static let iconFontSize: CGFloat = 22
        static let percentageFontSize: CGFloat = 26
        static let minimumTextScale: CGFloat = 0.72
        static let rangeExplanation = "Calculated from the remaining battery energy, recent consumption, "
            + "and eligible saved trips for this bike. Riding style, terrain, temperature, and conditions "
            + "can change the actual range."
    }
}
