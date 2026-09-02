import SwiftUI
import UIKit

struct OnboardingConnectionRecoveryView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let bikeTitle: String
    let formattedVIN: String
    let accessibilityVIN: String

    var body: some View {
        HStack(spacing: Constants.spacing) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text(bikeTitle)
                    .font(.headline)
                Text(formattedVIN)
                    .font(.caption.monospaced().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: .zero)
        }
        .padding(Constants.padding)
        .background { surfaceBackground }
        .clipShape(RoundedRectangle(cornerRadius: Constants.radius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bikeTitle). VIN \(accessibilityVIN). Connection needs attention.")
    }

    @ViewBuilder private var surfaceBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: Constants.radius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        } else {
            RoundedRectangle(cornerRadius: Constants.radius, style: .continuous)
                .fill(.thinMaterial)
        }
    }
}

private extension OnboardingConnectionRecoveryView {
    enum Constants {
        static let spacing: CGFloat = 14
        static let textSpacing: CGFloat = 4
        static let padding: CGFloat = 18
        static let radius: CGFloat = 20
    }
}
