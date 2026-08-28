import DesignSystem
import SwiftUI

struct DashboardSystemHealthHeader: View {
    let title: String
    let state: DashboardSystemHealthViewData

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.informational)
            Spacer()
            Circle()
                .fill(DashboardSystemHealthStyle.color(for: state.status))
                .frame(width: Constants.statusDotSize, height: Constants.statusDotSize)
            Text(state.statusText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private enum Constants {
        static let statusDotSize: CGFloat = 5
    }
}
