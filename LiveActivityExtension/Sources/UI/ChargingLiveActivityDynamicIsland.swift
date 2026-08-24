import ActivityKit
import DesignSystem
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct ChargingLiveActivityDynamicIsland {
    let context: ActivityViewContext<ChargingLiveActivityAttributes>

    var body: DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                ChargingLiveActivityBatterySummary(state: context.state, showsProgress: false)
                    .padding(.leading, DesignSpace.small)
            }
            DynamicIslandExpandedRegion(.center) {
                ChargingLiveActivityStatusView(state: context.state)
            }
            DynamicIslandExpandedRegion(.trailing) {
                ChargingLiveActivityMetricStack(state: context.state, mode: .compact)
                    .padding(.trailing, DesignSpace.small)
            }
            DynamicIslandExpandedRegion(.bottom) {
                ChargingLiveActivityProgressView(state: context.state)
                    .padding(.horizontal, DesignSpace.small)
            }
        } compactLeading: {
            Text(ChargingLiveActivityFormatter.batteryText(context.state.batteryPercent))
                .font(.caption2.bold())
                .monospacedDigit()
        } compactTrailing: {
            Image(systemName: ChargingLiveActivityIcon.name(for: context.state.phase))
                .foregroundStyle(ChargingLiveActivityPresentation.tint(for: context.state.phase))
        } minimal: {
            Text(ChargingLiveActivityFormatter.batteryText(context.state.batteryPercent))
                .font(.caption2.bold())
                .monospacedDigit()
                .foregroundStyle(ChargingLiveActivityPresentation.tint(for: context.state.phase))
        }
        .widgetURL(ChargingLiveActivityPresentation.widgetURL)
        .keylineTint(ChargingLiveActivityPresentation.tint(for: context.state.phase))
    }
}
