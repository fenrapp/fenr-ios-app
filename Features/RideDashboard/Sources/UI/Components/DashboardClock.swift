import DesignSystem
import SwiftUI

struct DashboardClock: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: Constants.refreshInterval)) { context in
            Text(context.date, format: .dateTime.hour().minute())
                .font(.system(
                    size: Constants.fontSize,
                    weight: .medium,
                    design: .rounded
                ))
                .monospacedDigit()
                .foregroundStyle(DesignColor.secondaryText)
                .accessibilityLabel(context.date.formatted(date: .omitted, time: .shortened))
        }
    }

    private enum Constants {
        static let fontSize: CGFloat = 22
        static let refreshInterval: TimeInterval = 30
    }
}
