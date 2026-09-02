import ActivityKit
import DesignSystem
import SwiftUI
import WidgetKit

struct BikeLiveActivityLockScreenView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let context: ActivityViewContext<BikeLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            header
            summary
            BikeLiveActivityProgressView(state: context.state)
            BikeLiveActivityMetricStack(state: context.state, mode: .regular)
        }
        .padding(.horizontal, DesignSpace.medium)
        .padding(.vertical, DesignSpace.small)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
            Text(BikeLiveActivityText.phase(context.state.phase))
                .font(.caption.weight(.semibold))
                .lineLimit(accessibilityLineLimit)
                .fixedSize(horizontal: false, vertical: usesAccessibilityLayout)
            Spacer(minLength: DesignSpace.extraSmall)
        }
    }

    @ViewBuilder
    private var summary: some View {
        if usesAccessibilityLayout {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                batterySummary
                modeAndStatus(alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: DesignSpace.small) {
                batterySummary
                Spacer(minLength: DesignSpace.extraSmall)
                modeAndStatus(alignment: .trailing)
            }
        }
    }

    private var batterySummary: some View {
        Text(BikeLiveActivityFormatter.batteryText(context.state.batteryPercent))
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .monospacedDigit()
            .lineLimit(accessibilityLineLimit)
            .minimumScaleFactor(Constants.batteryMinimumScale)
            .fixedSize(horizontal: false, vertical: usesAccessibilityLayout)
            .accessibilityLabel(
                BikeLiveActivityText.batteryAccessibilityLabel(context.state.batteryPercent)
            )
    }

    private func modeAndStatus(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DesignSpace.extraExtraSmall) {
            if context.state.mode == .charging {
                BikeLiveActivityTargetText(percent: context.state.targetPercent)
            } else {
                Text(BikeLiveActivityFormatter.modeText(context.state.modeIndex))
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(BikeLiveActivityPresentation.tint(for: context.state.phase))
                    .lineLimit(accessibilityLineLimit)
                    .fixedSize(horizontal: false, vertical: usesAccessibilityLayout)
                    .accessibilityLabel(
                        BikeLiveActivityText.modeAccessibilityLabel(context.state.modeIndex)
                    )
            }
            BikeLiveActivityStatusView(state: context.state)
        }
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var accessibilityLineLimit: Int? {
        usesAccessibilityLayout ? nil : BikeLiveActivityText.singleLineLimit
    }

    private enum Constants {
        static let batteryMinimumScale = 0.75
    }
}
