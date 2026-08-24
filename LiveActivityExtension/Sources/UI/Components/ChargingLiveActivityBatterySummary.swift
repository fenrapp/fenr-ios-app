import DesignSystem
import SwiftUI

struct ChargingLiveActivityBatterySummary: View {
    let state: ChargingLiveActivityAttributes.ContentState
    var showsProgress = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(ChargingLiveActivityFormatter.batteryText(state.batteryPercent))
                .font(.headline.bold())
                .monospacedDigit()
                .lineLimit(ChargingLiveActivityText.singleLineLimit)
            ChargingLiveActivityTargetText(percent: state.targetPercent)
            if showsProgress {
                ChargingLiveActivityProgressView(state: state)
            }
        }
    }
}
