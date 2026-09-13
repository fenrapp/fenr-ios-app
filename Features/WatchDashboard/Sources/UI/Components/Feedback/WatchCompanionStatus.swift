import DesignSystem
import SwiftUI

struct WatchCompanionStatus: View {
    let state: WatchDashboardViewState

    var body: some View {
        VStack(spacing: DesignSpace.extraExtraSmall) {
            Label {
                Text(verbatim: state.status)
            } icon: {
                Image(systemName: state.isStale ? "clock" : "iphone")
            }
            .lineLimit(1)
            .minimumScaleFactor(Constants.minimumScaleFactor)
            .foregroundStyle(state.isStale ? .orange : .secondary)
            if state.isStale, let updatedAt = state.updatedAt {
                Text(updatedAt, style: .relative)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text(.watchCompanionLastUpdate))
            }
        }
        .font(.system(size: Constants.fontSize))
        .multilineTextAlignment(.center)
    }

    private enum Constants {
        static let fontSize: CGFloat = 10
        static let minimumScaleFactor = 0.75
    }
}
