import DesignSystem
import SwiftUI

struct DashboardCompactSpeedReadout: View {
    let state: DashboardSpeedometerViewData

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.valueSpacing) {
            Text(state.valueText)
                .font(.system(size: Constants.valueFontSize, weight: .medium, design: .rounded))
            Text(state.unit)
                .font(.system(size: Constants.unitFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(Constants.minimumScaleFactor)
        .foregroundStyle(DesignColor.primaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private enum Constants {
        static let scale: CGFloat = 1.2
        static let valueFontSize: CGFloat = 44.2 * scale
        static let unitFontSize: CGFloat = 16.9 * scale
        static let valueSpacing: CGFloat = 3.9 * scale
        static let minimumScaleFactor: CGFloat = 0.7
    }
}
