import DesignSystem
import SwiftUI

struct ChargingLiveActivityStatusView: View {
    let state: ChargingLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: DesignSpace.extraExtraSmall) {
            Image(systemName: ChargingLiveActivityIcon.name(for: state.phase))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChargingLiveActivityPresentation.tint(for: state.phase))
            Text(statusText)
                .font(.caption.weight(.medium))
                .lineLimit(ChargingLiveActivityText.singleLineLimit)
                .minimumScaleFactor(Constants.minimumScale)
        }
    }

    private var statusText: String {
        if state.phase == .complete {
            return ChargingLiveActivityText.ready
        }
        if let estimatedTimeRemaining = state.estimatedTimeRemaining {
            return ChargingLiveActivityText.remaining(estimatedTimeRemaining)
        }
        return state.phase.displayTitle
    }

    private enum Constants {
        static let minimumScale = 0.8
    }
}
