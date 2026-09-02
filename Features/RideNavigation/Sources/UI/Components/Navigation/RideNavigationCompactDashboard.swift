import DesignSystem
import SwiftUI

struct RideNavigationCompactDashboard: View {
    let state: RideNavigationViewState

    var body: some View {
        Group {
            if isFocusDriving {
                Grid(horizontalSpacing: DesignSpace.medium, verticalSpacing: DesignSpace.small) {
                    GridRow {
                        RideNavigationMetric(
                            value: state.speedText,
                            unit: state.speedUnit,
                            label: .rideNavigationMetricSpeed
                        )
                        RideNavigationMetric(value: state.modeText, unit: "", label: .rideNavigationMetricPower)
                    }
                    GridRow {
                        RideNavigationMetric(value: state.batteryText, unit: "", label: .rideNavigationMetricBike)
                        RideNavigationMetric(value: state.elapsedText, unit: "", label: .rideNavigationMetricTime)
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DesignSpace.medium) { metrics }
                    VStack(alignment: .leading, spacing: DesignSpace.small) {
                        RideNavigationMetric(
                            value: state.speedText,
                            unit: state.speedUnit,
                            label: .rideNavigationMetricSpeed
                        )
                        RideNavigationMetric(value: state.modeText, unit: "", label: .rideNavigationMetricPower)
                        RideNavigationMetric(value: state.batteryText, unit: "", label: .rideNavigationMetricBike)
                    }
                }
            }
        }
        .padding(.horizontal, DesignSpace.large)
        .padding(.vertical, DesignSpace.small)
        .frame(minHeight: Constants.height)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
        .frame(maxWidth: isFocusDriving ? Constants.focusMaximumWidth : Constants.maximumWidth)
        .frame(maxWidth: .infinity, alignment: isFocusDriving ? .leading : .center)
    }

    @ViewBuilder
    private var metrics: some View {
        RideNavigationMetric(value: state.speedText, unit: state.speedUnit, label: .rideNavigationMetricSpeed)
        divider
        RideNavigationMetric(value: state.modeText, unit: "", label: .rideNavigationMetricPower)
        divider
        RideNavigationMetric(value: state.batteryText, unit: "", label: .rideNavigationMetricBike)
    }

    private var divider: some View {
        Divider().frame(height: Constants.dividerHeight)
    }

    private var isFocusDriving: Bool {
        state.mapScene.displayStyle == .focus
            && (state.activity == .following || state.activity == .navigating)
    }

    private enum Constants {
        static let height: CGFloat = 76
        static let cornerRadius: CGFloat = 24
        static let dividerHeight: CGFloat = 32
        static let maximumWidth: CGFloat = 460
        static let focusMaximumWidth: CGFloat = 220
    }
}
