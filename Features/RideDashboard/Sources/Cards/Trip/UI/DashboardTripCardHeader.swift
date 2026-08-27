import DesignSystem
import SwiftUI

struct DashboardTripCardHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: DesignSpace.small) {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(DashboardTripCardHeaderConstants.titleTracking)
                    .foregroundStyle(DesignColor.informational)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignColor.secondaryText)
                }
            }
            Spacer()
            trailing
        }
    }
}

extension DashboardTripCardHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, trailing: EmptyView.init)
    }
}

private enum DashboardTripCardHeaderConstants {
    static let titleTracking: CGFloat = 1.1
}
