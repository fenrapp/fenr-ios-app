import DesignSystem
import SwiftUI

struct RideHistoryDetailHeader: View {
    let state: RideHistoryDetailViewState

    var body: some View {
        VStack(spacing: DesignSpace.small) {
            Image(systemName: "motorcycle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .background(.tint.opacity(Constants.iconBackgroundOpacity), in: Circle())

            VStack(spacing: Constants.textSpacing) {
                Text(state.distanceText)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(state.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(state.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSpace.extraSmall)
        .accessibilityElement(children: .combine)
    }

    private enum Constants {
        static let iconSize: CGFloat = 52
        static let iconBackgroundOpacity = 0.12
        static let textSpacing: CGFloat = 3
    }
}
