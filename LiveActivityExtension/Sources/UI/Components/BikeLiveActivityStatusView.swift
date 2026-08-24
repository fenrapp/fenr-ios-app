import DesignSystem
import SwiftUI

struct BikeLiveActivityStatusView: View {
    let state: BikeLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: DesignSpace.extraExtraSmall) {
            Image(systemName: BikeLiveActivityIcon.name(for: state.phase))
                .font(.caption.weight(.semibold))
                .foregroundStyle(BikeLiveActivityPresentation.tint(for: state.phase))
            Text(statusText)
                .font(.caption.weight(.medium))
                .lineLimit(BikeLiveActivityText.singleLineLimit)
                .minimumScaleFactor(Constants.minimumScale)
        }
    }

    private var statusText: String {
        if state.phase == .complete {
            return BikeLiveActivityText.ready
        }
        if let estimatedTimeRemaining = state.estimatedTimeRemaining {
            return BikeLiveActivityText.remaining(estimatedTimeRemaining)
        }
        if state.mode == .riding {
            return state.runState.displayTitle
        }
        return state.phase.displayTitle
    }

    private enum Constants {
        static let minimumScale = 0.8
    }
}
