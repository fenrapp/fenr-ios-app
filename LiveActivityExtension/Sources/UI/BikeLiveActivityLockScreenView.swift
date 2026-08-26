import ActivityKit
import DesignSystem
import SwiftUI
import WidgetKit

struct BikeLiveActivityLockScreenView: View {
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
            Text(context.state.phase.displayTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(BikeLiveActivityText.singleLineLimit)
            Spacer(minLength: DesignSpace.extraSmall)
            Text(BikeLiveActivityFormatter.shortIdentifier(context.attributes.vin))
                .font(.caption2.monospaced())
                .foregroundStyle(DesignColor.secondaryText)
                .lineLimit(BikeLiveActivityText.singleLineLimit)
                .minimumScaleFactor(Constants.identifierMinimumScale)
        }
    }

    private var summary: some View {
        HStack(alignment: .lastTextBaseline, spacing: DesignSpace.small) {
            Text(BikeLiveActivityFormatter.batteryText(context.state.batteryPercent))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(BikeLiveActivityText.singleLineLimit)
                .minimumScaleFactor(Constants.batteryMinimumScale)
            Spacer(minLength: DesignSpace.extraSmall)
            VStack(alignment: .trailing, spacing: DesignSpace.extraExtraSmall) {
                if context.state.mode == .charging {
                    BikeLiveActivityTargetText(percent: context.state.targetPercent)
                } else {
                    Text(BikeLiveActivityFormatter.modeText(context.state.modeIndex))
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(BikeLiveActivityPresentation.tint(for: context.state.phase))
                        .lineLimit(BikeLiveActivityText.singleLineLimit)
                }
                BikeLiveActivityStatusView(state: context.state)
            }
        }
    }

    private enum Constants {
        static let batteryMinimumScale = 0.75
        static let identifierMinimumScale = 0.8
    }
}
