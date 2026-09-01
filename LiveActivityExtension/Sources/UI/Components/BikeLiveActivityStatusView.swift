import DesignSystem
import SwiftUI

struct BikeLiveActivityStatusView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let state: BikeLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: DesignSpace.extraExtraSmall) {
            Image(systemName: BikeLiveActivityIcon.name(for: state.phase))
                .font(.caption.weight(.semibold))
                .foregroundStyle(BikeLiveActivityPresentation.tint(for: state.phase))
            Text(statusText)
                .font(.caption.weight(.medium))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : BikeLiveActivityText.singleLineLimit)
                .minimumScaleFactor(Constants.minimumScale)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BikeLiveActivityText.statusAccessibilityLabel(state))
    }

    private var statusText: String {
        BikeLiveActivityText.status(state)
    }

    private enum Constants {
        static let minimumScale = 0.8
    }
}
