import DesignSystem
import SwiftUI

struct DashboardPowerModeStrip: View {
    let state: DashboardPowerModeViewData

    var body: some View {
        HStack(spacing: .zero) {
            metric(label: "MODE", value: state.map, unit: nil, tint: DesignColor.positive)
            divider
            metric(label: "POWER", value: state.horsepower, unit: "HP")
            divider
            metric(label: "REGEN", value: state.regenerativeBraking, unit: "%")
            if state.showsTractionControl {
                divider
                metric(label: "TC POWER", value: state.powerTraction, unit: "%")
                divider
                metric(label: "TC REGEN", value: state.brakingTraction, unit: "%")
            }
        }
        .padding(.horizontal, DesignSpace.extraSmall)
        .padding(.vertical, DesignSpace.extraExtraSmall)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            DesignColor.elevatedSurface,
            in: RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                .stroke(DesignColor.border, lineWidth: Constants.borderWidth)
        }
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColor.border)
            .frame(width: Constants.dividerWidth, height: Constants.dividerHeight)
            .padding(.horizontal, DesignSpace.extraExtraSmall)
    }

    private func metric(
        label: String,
        value: String,
        unit: String?,
        tint: Color = DesignColor.primaryText
    ) -> some View {
        VStack(spacing: Constants.metricSpacing) {
            Text(label)
                .font(.system(size: Constants.labelFontSize, weight: .semibold))
                .foregroundStyle(DesignColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(Constants.labelMinimumScaleFactor)
            HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
                Text(value)
                    .font(.system(size: Constants.valueFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.valueMinimumScaleFactor)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.system(size: Constants.unitFontSize, weight: .medium))
                        .foregroundStyle(DesignColor.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private enum Constants {
        static let borderWidth: CGFloat = 1
        static let dividerWidth: CGFloat = 1
        static let dividerHeight: CGFloat = 30
        static let metricSpacing: CGFloat = 2
        static let labelFontSize: CGFloat = 9
        static let valueFontSize: CGFloat = 20
        static let unitFontSize: CGFloat = 10
        static let labelMinimumScaleFactor = 0.65
        static let valueMinimumScaleFactor = 0.65
    }
}

#Preview("Power and regen") {
    DashboardPowerModeStrip(state: .init(
        map: "4",
        horsepower: "60",
        regenerativeBraking: "50"
    ))
    .frame(width: 520, height: 62)
}

#Preview("Power, regen and TC") {
    DashboardPowerModeStrip(state: .init(
        map: "5",
        horsepower: "80",
        regenerativeBraking: "40",
        powerTraction: "35",
        brakingTraction: "12.5",
        showsTractionControl: true
    ))
    .frame(width: 640, height: 62)
}

#Preview("Partial data") {
    DashboardPowerModeStrip(state: .init(map: "2"))
        .frame(width: 520, height: 62)
}
