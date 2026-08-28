import DesignSystem
import SwiftUI

struct DashboardOdometerLabel: View {
    let state: DashboardOdometerViewData

    var body: some View {
        Label(state.valueText, systemImage: "gauge.with.dots.needle.67percent")
            .font(.system(size: Constants.fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(DesignColor.primaryText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(Constants.minimumScaleFactor)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilityLabel)
    }

    private enum Constants {
        static let fontSize: CGFloat = 16
        static let minimumScaleFactor = 0.75
    }
}
