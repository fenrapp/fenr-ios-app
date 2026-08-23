import DesignSystem
import SwiftUI

struct DashboardBatteryPanel: View {
    let percentage: Int?
    let compact: Bool

    private var clampedPercentage: Int {
        min(max(percentage ?? .zero, .zero), Constants.maximumPercentage)
    }

    private var fillFraction: CGFloat {
        CGFloat(clampedPercentage) / CGFloat(Constants.maximumPercentage)
    }

    private var tint: Color {
        guard let percentage else { return .primary }
        return switch percentage {
        case ..<Constants.criticalPercentage: DesignColor.critical
        case ..<Constants.warningPercentage: DesignColor.warning
        default: DesignColor.positive
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? DesignSpace.extraSmall : DesignSpace.small) {
            HStack(alignment: .center, spacing: compact ? DesignSpace.extraSmall : DesignSpace.small) {
                percentageValue

                DashboardBatteryGlyph(
                    fillFraction: fillFraction,
                    fillColor: tint,
                    compact: compact
                )
                    .accessibilityHidden(true)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { proxy in
                Capsule()
                    .fill(DesignColor.inactive)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * fillFraction)
                    }
            }
            .frame(height: Constants.progressHeight)
            .animation(Constants.valueAnimation, value: fillFraction)
        }
        .frame(maxWidth: Constants.maximumWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(percentage.map { "\($0) percent" } ?? "unavailable")")
    }

    private var percentageValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.percentageSignSpacing) {
            Text(percentage.map(String.init) ?? "—")
                .font(.system(
                    size: basePercentageFontSize * Constants.percentageValueScale,
                    weight: .medium,
                    design: .rounded
                ))
                .contentTransition(.numericText())

            if percentage != nil {
                Text("%")
                    .font(.system(
                        size: basePercentageFontSize * Constants.percentageSignScale,
                        weight: .medium,
                        design: .rounded
                    ))
            }
        }
        .foregroundStyle(.primary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .animation(Constants.valueAnimation, value: clampedPercentage)
    }

    private var basePercentageFontSize: CGFloat {
        compact ? Constants.compactPercentageFontSize : Constants.percentageFontSize
    }

    private enum Constants {
        static let maximumPercentage = 100
        static let maximumWidth: CGFloat = 240
        static let percentageFontSize: CGFloat = 46
        static let compactPercentageFontSize: CGFloat = 30
        static let percentageValueScale: CGFloat = 1.2
        static let percentageSignScale: CGFloat = 0.3
        static let percentageSignSpacing: CGFloat = 2
        static let progressHeight: CGFloat = 8
        static let criticalPercentage = 15
        static let warningPercentage = 35
        static let valueAnimation = Animation.spring(response: 0.5, dampingFraction: 0.82)
    }
}
