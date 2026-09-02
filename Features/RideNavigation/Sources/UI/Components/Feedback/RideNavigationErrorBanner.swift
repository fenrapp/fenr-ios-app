import DesignSystem
import SwiftUI

struct RideNavigationErrorBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(DesignColor.critical)
            .padding(DesignSpace.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignColor.critical.opacity(Constants.backgroundOpacity),
                in: RoundedRectangle(cornerRadius: DesignRadius.medium)
            )
    }

    private enum Constants {
        static let backgroundOpacity = 0.12
    }
}
