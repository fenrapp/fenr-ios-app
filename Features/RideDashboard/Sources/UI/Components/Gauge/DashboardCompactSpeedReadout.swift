import DesignSystem
import SwiftUI

struct DashboardCompactSpeedReadout: View {
    let state: DashboardSpeedometerViewData

    var body: some View {
        ViewThatFits(in: .horizontal) {
            readout(scale: Constants.scale)
                .fixedSize(horizontal: true, vertical: false)
            readout(scale: Constants.compactScale)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(height: DashboardSideStatusLayoutMetrics.secondaryStatusHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private func readout(scale: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.valueSpacing) {
            Text(state.valueText)
                .font(.system(size: Constants.valueFontSize * scale, weight: .medium, design: .rounded))
            Text(state.unit)
                .font(.system(size: Constants.unitFontSize * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(Constants.minimumScaleFactor)
        .foregroundStyle(DesignColor.primaryText)
    }

    private enum Constants {
        static let scale: CGFloat = 1.2
        static let compactScale: CGFloat = 0.8
        static let horizontalPadding: CGFloat = 6
        static let valueFontSize: CGFloat = 44.2
        static let unitFontSize: CGFloat = 16.9
        static let valueSpacing: CGFloat = 3.9 * scale
        static let minimumScaleFactor: CGFloat = 0.7
    }
}
