import DesignSystem
import SwiftUI

struct RideNavigationCompactDashboard: View {
    let state: RideNavigationViewState

    var body: some View {
        HStack(spacing: DesignSpace.medium) {
            RideNavigationMetric(value: state.speedText, unit: state.speedUnit, label: "Speed")
            divider
            RideNavigationMetric(value: state.modeText, unit: "", label: "Power")
            divider
            RideNavigationMetric(value: state.batteryText, unit: "", label: "Bike")
        }
        .padding(.horizontal, DesignSpace.large)
        .padding(.vertical, DesignSpace.small)
        .frame(minHeight: Constants.height)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
        .frame(maxWidth: Constants.maximumWidth)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var divider: some View {
        Divider().frame(height: Constants.dividerHeight)
    }

    private enum Constants {
        static let height: CGFloat = 76
        static let cornerRadius: CGFloat = 24
        static let dividerHeight: CGFloat = 32
        static let maximumWidth: CGFloat = 460
    }
}
