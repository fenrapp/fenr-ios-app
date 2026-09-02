import DesignSystem
import SwiftUI

struct DashboardTripMetricRow<Accessory: View>: View {
    let label: String
    let valueText: String
    let unit: String
    let systemImage: String
    private let accessory: Accessory

    init(
        label: String,
        valueText: String,
        unit: String,
        systemImage: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.valueText = valueText
        self.unit = unit
        self.systemImage = systemImage
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: DesignSpace.small) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(DesignColor.informational)
                .frame(width: DashboardTripMetricRowConstants.iconWidth)
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(DesignColor.primaryText)
                .lineLimit(1)
                .layoutPriority(1)
            accessory
            Spacer(minLength: DesignSpace.small)
            HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
                Text(valueText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignColor.primaryText)
                Text(unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(verbatim: "\(valueText) \(unit)"))
    }
}

extension DashboardTripMetricRow where Accessory == EmptyView {
    init(
        label: String,
        valueText: String,
        unit: String,
        systemImage: String
    ) {
        self.init(
            label: label,
            valueText: valueText,
            unit: unit,
            systemImage: systemImage,
            accessory: EmptyView.init
        )
    }
}

private enum DashboardTripMetricRowConstants {
    static let iconWidth: CGFloat = 22
}
