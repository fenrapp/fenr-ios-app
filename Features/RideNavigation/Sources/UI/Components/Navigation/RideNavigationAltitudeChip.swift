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
                .minimumScaleFactor(Constants.minimumScaleFactor)
                .allowsTightening(true)
        } icon: {
            Image(systemName: "mountain.2.fill")
        }
        .lineLimit(1)
        .padding(.horizontal, DesignSpace.small)
        .frame(minHeight: Constants.minimumHeight)
        .rideNavigationGlassChip()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.rideNavigationMetricAltitude)
        .accessibilityValue(Text(verbatim: "\(value) \(unit)"))
    }

    private enum Constants {
        static let minimumHeight: CGFloat = 44
        static let minimumScaleFactor = 0.65
    }
}
