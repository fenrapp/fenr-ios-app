import DesignSystem
import SwiftUI

struct DashboardMetricPanel: View {
    let title: String
    let measurement: RideDashboardMeasurement?
    let fractionDigits: Int
    let tint: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: DesignSpace.extraSmall) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
                Text(formattedValue)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.minimumScaleFactor)
                    .contentTransition(.numericText())
                    .animation(Constants.valueAnimation, value: measurement?.value)
                if let unit = measurement?.unit {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignColor.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var formattedValue: String {
        guard let measurement else { return "—" }
        return measurement.value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    private enum Constants {
        static let minimumScaleFactor = 0.7
        static let valueAnimation = Animation.spring(response: 0.45, dampingFraction: 0.84)
    }
}
