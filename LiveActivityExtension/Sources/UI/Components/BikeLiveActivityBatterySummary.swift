import DesignSystem
import SwiftUI

struct BikeLiveActivityBatterySummary: View {
    let state: BikeLiveActivityAttributes.ContentState
    var showsProgress = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(BikeLiveActivityFormatter.batteryText(state.batteryPercent))
                .font(.headline.bold())
                .monospacedDigit()
                .lineLimit(BikeLiveActivityText.singleLineLimit)
            if state.mode == .charging {
                BikeLiveActivityTargetText(percent: state.targetPercent)
            } else {
                Text(BikeLiveActivityFormatter.modeText(state.modeIndex))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BikeLiveActivityPresentation.tint(for: state.phase))
                    .lineLimit(BikeLiveActivityText.singleLineLimit)
            }
            if showsProgress {
                BikeLiveActivityProgressView(state: state)
            }
        }
    }
}
