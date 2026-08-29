import DesignSystem
import SwiftUI

struct RideNavigationTrailExitPreviewCard: View {
    let preview: RideNavigationTrailExitPreview
    let onCancel: () -> Void
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: DesignSpace.medium) {
            Image(systemName: "road.lanes")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(preview.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(preview.detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignSpace.medium)
            Button("Keep Following Trail", action: onCancel)
                .rideNavigationSecondaryButton()
            Button("Start Exit", action: onStart)
                .rideNavigationPrimaryButton()
        }
        .padding(DesignSpace.medium)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
    }

    private enum Constants {
        static let cornerRadius: CGFloat = 18
    }
}
