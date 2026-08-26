import DesignSystem
import SwiftUI

struct DashboardSpeedSourceChip: View {
    let state: DashboardSpeedSourceIndicatorViewData

    var body: some View {
        let tint = switch state.emphasis {
        case .informational: DesignColor.informational
        case .warning: DesignColor.warning
        }
        Label(state.text, systemImage: state.systemImage)
            .font(.caption2.weight(.bold))
            .tracking(Constants.tracking)
            .foregroundStyle(tint)
            .padding(.horizontal, Constants.horizontalPadding)
            .frame(height: Constants.height)
            .fixedSize(horizontal: true, vertical: false)
            .background(Capsule().fill(DesignColor.groupedSurface))
            .overlay {
                Capsule()
                    .stroke(tint.opacity(Constants.outlineOpacity))
            }
            .accessibilityLabel("(state.text) speed source")
    }

    private enum Constants {
        static let height: CGFloat = 22
        static let horizontalPadding: CGFloat = 10
        static let tracking: CGFloat = 0.7
        static let outlineOpacity = 0.45
    }
}
