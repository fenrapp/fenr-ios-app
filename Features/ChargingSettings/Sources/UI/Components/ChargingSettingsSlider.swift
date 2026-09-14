import DesignSystem
import SwiftUI

struct ChargingSettingsSlider: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringResource
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let detail: String
    let isEnabled: Bool
    let isPower: Bool
    let commit: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            CommitSlider(
                value: value,
                in: range,
                step: step,
                appearance: Constants.appearance,
                isEnabled: isEnabled,
                allowsUnchangedCommit: true,
                accessibilityLabel: String(localized: title),
                accessibilityValue: formattedValue,
                onCommit: commit,
                header: { displayedValue in
                    header(displayedValue)
                },
                footer: {
                    HStack {
                        Text(verbatim: formattedValue(range.lowerBound))
                        Spacer()
                        Text(verbatim: formattedValue(range.upperBound))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DesignColor.secondaryText)
                }
            )
            Text(verbatim: detail)
                .font(.footnote)
                .foregroundStyle(DesignColor.secondaryText)
        }
        .padding(.vertical, DesignSpace.extraExtraSmall)
    }

    @ViewBuilder
    private func header(_ displayedValue: Double) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(title)
                    .font(.callout.weight(.medium))
                valueLabel(displayedValue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer()
                valueLabel(displayedValue)
            }
        }
    }

    private func valueLabel(_ displayedValue: Double) -> some View {
        Text(verbatim: formattedValue(displayedValue))
            .font(.callout.weight(.semibold))
            .monospacedDigit()
    }

    private func formattedValue(_ selected: Double) -> String {
        isPower
            ? Measurement(value: selected, unit: UnitPower.watts)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided))
            : (selected / 100).formatted(.percent)
    }

    @MainActor private enum Constants {
        static let appearance = CommitSliderAppearance(
            gradientStops: [
                .init(color: .teal, location: 0),
                .init(color: .blue, location: 1)
            ]
        )
    }
}
