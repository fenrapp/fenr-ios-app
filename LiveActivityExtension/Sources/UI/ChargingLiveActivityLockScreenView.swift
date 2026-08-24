import ActivityKit
import DesignSystem
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct ChargingLiveActivityLockScreenView: View {
    let context: ActivityViewContext<ChargingLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            header
            summary
            ChargingLiveActivityProgressView(state: context.state)
            ChargingLiveActivityMetricStack(state: context.state, mode: .regular)
        }
        .padding(.horizontal, DesignSpace.medium)
        .padding(.vertical, DesignSpace.small)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
            Text(context.state.phase.displayTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(ChargingLiveActivityText.singleLineLimit)
            Spacer(minLength: DesignSpace.extraSmall)
            Text(ChargingLiveActivityFormatter.shortIdentifier(context.attributes.vin))
                .font(.caption2.monospaced())
                .foregroundStyle(DesignColor.secondaryText)
                .lineLimit(ChargingLiveActivityText.singleLineLimit)
                .minimumScaleFactor(Constants.identifierMinimumScale)
        }
    }

    private var summary: some View {
        HStack(alignment: .lastTextBaseline, spacing: DesignSpace.small) {
            Text(ChargingLiveActivityFormatter.batteryText(context.state.batteryPercent))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(ChargingLiveActivityText.singleLineLimit)
                .minimumScaleFactor(Constants.batteryMinimumScale)
            Spacer(minLength: DesignSpace.extraSmall)
            VStack(alignment: .trailing, spacing: DesignSpace.extraExtraSmall) {
                ChargingLiveActivityTargetText(percent: context.state.targetPercent)
                ChargingLiveActivityStatusView(state: context.state)
            }
        }
    }

    private enum Constants {
        static let batteryMinimumScale = 0.75
        static let identifierMinimumScale = 0.8
    }
}
