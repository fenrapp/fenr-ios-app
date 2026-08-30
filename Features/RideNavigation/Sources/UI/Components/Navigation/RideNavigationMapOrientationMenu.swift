import DesignSystem
import SwiftUI

struct RideNavigationMapOrientationMenu: View {
    let isHeadingUp: Bool
    let isPresented: Bool
    let onPresentationChange: (Bool) -> Void

    var body: some View {
        Button {
            onPresentationChange(!isPresented)
        } label: {
            RideNavigationMapControlLabel(systemImage: "safari.fill")
        }
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel("Map orientation, \(isHeadingUp ? "Heading Up" : "North Up")")
    }
}

struct RideNavigationMapOrientationPicker: View {
    let isHeadingUp: Bool
    let onSelect: (Bool) -> Void

    private func orientationButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        value: Bool
    ) -> some View {
        Button {
            onSelect(value)
        } label: {
            HStack(spacing: Constants.rowSpacing) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: Constants.rowSpacing)
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: Constants.rowHeight, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            Text("Map Orientation")
                .font(.headline)
            orientationButton(
                title: "Heading Up",
                systemImage: "location.north.fill",
                isSelected: isHeadingUp,
                value: true
            )
            orientationButton(
                title: "North Up",
                systemImage: "location.north.circle",
                isSelected: !isHeadingUp,
                value: false
            )
        }
        .padding(Constants.popoverPadding)
        .frame(width: Constants.popoverWidth)
        .rideNavigationGlassSurface(cornerRadius: Constants.popoverCornerRadius)
    }

    private enum Constants {
        static let popoverWidth: CGFloat = 220
        static let popoverPadding: CGFloat = 16
        static let popoverCornerRadius: CGFloat = 20
        static let rowHeight: CGFloat = 40
        static let rowSpacing: CGFloat = 10
    }
}
