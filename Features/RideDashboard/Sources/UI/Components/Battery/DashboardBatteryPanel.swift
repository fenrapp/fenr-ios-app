import DesignSystem
import SwiftUI

struct DashboardBatteryPanel: View {
    let state: RideDashboardViewState.Battery

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            Image(systemName: "bolt.fill")
                .font(.system(size: Constants.iconFontSize, weight: .semibold))
                .accessibilityHidden(true)

            Text(percentageText)
                .font(.system(size: Constants.percentageFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .frame(width: Constants.width, height: Constants.height)
        .background {
            Capsule()
                .fill(tint.opacity(Constants.backgroundOpacity))
        }
        .overlay {
            Capsule()
                .stroke(tint, lineWidth: Constants.outlineWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var percentageText: String {
        guard state.percentageText.hasSuffix("%") else { return state.percentageText }
        return String(state.percentageText.dropLast())
    }

    private var tint: Color {
        switch state.emphasis {
        case .unavailable: DesignColor.secondaryText
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let width: CGFloat = 112
        static let height: CGFloat = 60
        static let outlineWidth: CGFloat = 2.75
        static let backgroundOpacity = 0.08
        static let iconFontSize: CGFloat = 22
        static let percentageFontSize: CGFloat = 26
    }
}
