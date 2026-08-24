import ActivityKit
import DesignSystem
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct BikeLiveActivityDynamicIsland {
    let context: ActivityViewContext<BikeLiveActivityAttributes>

    var body: DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                BikeLiveActivityBatterySummary(state: context.state, showsProgress: false)
                    .padding(.leading, DesignSpace.small)
            }
            DynamicIslandExpandedRegion(.center) {
                BikeLiveActivityStatusView(state: context.state)
            }
            DynamicIslandExpandedRegion(.trailing) {
                BikeLiveActivityMetricStack(state: context.state, mode: .compact)
                    .padding(.trailing, DesignSpace.small)
            }
            DynamicIslandExpandedRegion(.bottom) {
                BikeLiveActivityProgressView(state: context.state)
                    .padding(.horizontal, DesignSpace.small)
            }
        } compactLeading: {
            Text(BikeLiveActivityFormatter.batteryText(context.state.batteryPercent))
                .font(.caption2.bold())
                .monospacedDigit()
        } compactTrailing: {
            compactTrailing
        } minimal: {
            Text(BikeLiveActivityFormatter.batteryText(context.state.batteryPercent))
                .font(.caption2.bold())
                .monospacedDigit()
                .foregroundStyle(BikeLiveActivityPresentation.tint(for: context.state.phase))
        }
        .widgetURL(BikeLiveActivityPresentation.widgetURL)
        .keylineTint(BikeLiveActivityPresentation.tint(for: context.state.phase))
    }

    @ViewBuilder
    private var compactTrailing: some View {
        if context.state.mode == .riding, !context.state.isFaultActive, !context.state.isConnectionLost {
            Text(BikeLiveActivityFormatter.modeText(context.state.modeIndex))
                .font(.caption2.bold())
                .monospacedDigit()
                .foregroundStyle(BikeLiveActivityPresentation.tint(for: context.state.phase))
        } else {
            Image(systemName: BikeLiveActivityIcon.name(for: context.state.phase))
                .foregroundStyle(BikeLiveActivityPresentation.tint(for: context.state.phase))
        }
    }
}
