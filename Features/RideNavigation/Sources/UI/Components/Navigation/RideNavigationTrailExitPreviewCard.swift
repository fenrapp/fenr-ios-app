import DesignSystem
import SwiftUI

struct RideNavigationTrailExitPreviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let preview: RideNavigationTrailExitPreview
    let onCancel: () -> Void
    let onStart: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignSpace.medium) { content }
            } else {
                HStack(spacing: DesignSpace.medium) { content }
            }
        }
        .padding(DesignSpace.medium)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
    }

    @ViewBuilder
    private var content: some View {
            Image(systemName: "road.lanes")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(preview.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                Text(preview.detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: DesignSpace.medium)
            }
            Button("Keep Following Trail", action: onCancel)
                .rideNavigationSecondaryButton()
            Button("Start Exit", action: onStart)
                .rideNavigationPrimaryButton()
    }

    private enum Constants {
        static let cornerRadius: CGFloat = 18
    }
}
