import DesignSystem
import SwiftUI

struct WatchDashboardMetric: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(spacing: DesignSpace.extraExtraSmall) {
            Text(title)
                .font(.system(size: Constants.titleSize))
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumScaleFactor)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumScaleFactor)
        }
        .frame(maxWidth: .infinity)
    }

    private enum Constants {
        static let titleSize: CGFloat = 10
        static let minimumScaleFactor = 0.6
    }
}
