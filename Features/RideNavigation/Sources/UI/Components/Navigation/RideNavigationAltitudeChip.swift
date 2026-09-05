import DesignSystem
import SwiftUI

struct RideNavigationAltitudeChip: View {
    let value: String
    let unit: String

    var body: some View {
        Label {
            Text(verbatim: "\(value) \(unit)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        } icon: {
            Image(systemName: "mountain.2.fill")
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, DesignSpace.small)
        .frame(minHeight: Constants.minimumHeight)
        .rideNavigationGlassChip()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.rideNavigationMetricAltitude)
        .accessibilityValue(Text(verbatim: "\(value) \(unit)"))
        .accessibilityIdentifier("rideNavigation.altitude")
    }

    private enum Constants {
        static let minimumHeight: CGFloat = 44
    }
}
