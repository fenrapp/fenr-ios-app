import DesignSystem
import SwiftUI

struct BatteryHealthBannerView: View {
    let banner: BatteryHealthBannerViewData

    var body: some View {
        HStack(alignment: .top, spacing: DesignSpace.small) {
            Image(systemName: imageName)
                .foregroundStyle(color)
                .frame(minWidth: Constants.minimumControlSize, minHeight: Constants.minimumControlSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(banner.title)
                    .font(.headline)
                Text(banner.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var imageName: String {
        switch banner.kind {
        case .fault, .write: "exclamationmark.octagon.fill"
        case .stale: "clock.badge.exclamationmark"
        case .monitoring: "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var color: Color {
        switch banner.emphasis {
        case .neutral: .secondary
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let minimumControlSize: CGFloat = 44
    }
}
