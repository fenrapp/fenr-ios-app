import DesignSystem
import SwiftUI

struct BikeDemoScenarioRow: View {
    let scenario: BikeDemoViewState.Scenario
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignSpace.medium) {
            Image(systemName: scenario.icon)
                .font(.title2)
                .foregroundStyle(DesignColor.warning)
                .frame(width: Constants.iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                Text(scenario.title).font(.headline).foregroundStyle(.primary)
                Text(scenario.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: .zero)
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(DesignColor.warning).accessibilityHidden(true)
            }
        }
        .padding(.vertical, DesignSpace.extraSmall)
        .accessibilityElement(children: .combine)
    }

    private enum Constants {
        static let iconWidth: CGFloat = 32
    }
}
