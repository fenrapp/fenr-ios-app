import DesignSystem
import SwiftUI

struct WatchDashboardMetric: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(spacing: DesignSpace.extraExtraSmall) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumScaleFactor)
        }
        .frame(maxWidth: .infinity)
    }

    private enum Constants {
        static let minimumScaleFactor = 0.7
    }
}

#if DEBUG
#Preview {
    WatchDashboardMetric(title: .watchDashboardOdometer, value: "180.0 km")
        .padding()
}
#endif
