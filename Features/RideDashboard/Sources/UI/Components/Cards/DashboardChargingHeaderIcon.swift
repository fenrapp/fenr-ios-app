import SwiftUI

struct DashboardChargingHeaderIcon: View {
    let systemImage: String
    let color: Color
    let showsActivityIndicator: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(Constants.backgroundOpacity))
            if showsActivityIndicator {
                ProgressView()
                    .controlSize(.large)
                    .tint(color)
                Image(systemName: systemImage)
                    .font(.system(size: Constants.activityIconSize, weight: .bold))
                    .foregroundStyle(color)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: Constants.iconSize, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: Constants.containerSize, height: Constants.containerSize)
        .accessibilityHidden(true)
    }

    private enum Constants {
        static let containerSize: CGFloat = 68
        static let iconSize: CGFloat = 30
        static let activityIconSize: CGFloat = 13
        static let backgroundOpacity = 0.14
    }
}
