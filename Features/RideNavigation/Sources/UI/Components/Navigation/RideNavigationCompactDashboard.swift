import DesignSystem
import SwiftUI

struct RideNavigationCompactDashboard: View {
    let state: RideNavigationViewState

    var rangeState = RideNavigationRangeState()
    var showsEstimatedRange = false
    var onToggleBatteryDisplay: () -> Void = {}

    var body: some View {
        RideNavigationMetricsRow(
            state: state, rangeState: rangeState, showsEstimatedRange: showsEstimatedRange,
            onToggleBatteryDisplay: onToggleBatteryDisplay
        )
        .padding(.horizontal, DesignSpace.large)
        .padding(.vertical, DesignSpace.small)
        .frame(minHeight: Constants.height)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
        .frame(maxWidth: isFocusDriving ? Constants.focusMaximumWidth : Constants.maximumWidth)
        .frame(maxWidth: .infinity, alignment: isFocusDriving ? .leading : .center)
    }

    private var isFocusDriving: Bool {
        state.mapScene.displayStyle == .focus
            && (state.activity == .following || state.activity == .navigating)
    }

    private enum Constants {
        static let height: CGFloat = 76
        static let cornerRadius: CGFloat = 24
        static let maximumWidth: CGFloat = 260
        static let focusMaximumWidth: CGFloat = 220
    }
}
