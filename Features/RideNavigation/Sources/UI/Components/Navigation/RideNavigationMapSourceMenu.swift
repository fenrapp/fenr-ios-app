import DesignSystem
import SwiftUI

struct RideNavigationMapSourceMenu: View {
    let sources: [MapSourceDescriptor]
    let selectedStyleID: String
    let allowsFocus: Bool
    let isPresented: Bool
    let onPresentationChange: (Bool) -> Void

    var body: some View {
        Button {
            onPresentationChange(!isPresented)
        } label: {
            RideNavigationMapControlLabel(systemImage: "map.fill")
        }
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel(.rideNavigationMapStyleAccessibility)
        .accessibilityValue(selectedStyleTitle)
    }

    private var selectedStyleTitle: String {
        if selectedStyleID == Constants.focusStyleID { return String(localized: .rideNavigationMapStyleFocus) }
        return sources.first(where: { $0.id == selectedStyleID })?.title
            ?? String(localized: .rideNavigationMapStyleFallback)
    }

    private enum Constants {
        static let focusStyleID = "focus"
    }
}

struct RideNavigationMapSourcePicker: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let sources: [MapSourceDescriptor]
    let selectedStyleID: String
    let allowsFocus: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            Text(.rideNavigationMapStyleTitle)
                .font(.headline)
            if allowsFocus {
                styleButton(
                    title: String(localized: .rideNavigationMapStyleFocus),
                    systemImage: "location.north.line.fill",
                    id: Constants.focusStyleID
                )
            }
            ForEach(sources) { source in
                styleButton(
                    title: source.title,
                    systemImage: source.id == MapSourceDescriptor.appleHybrid.id
                        ? "globe.americas.fill"
                        : "map.fill",
                    id: source.id
                )
            }
        }
        .padding(Constants.popoverPadding)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : Constants.popoverWidth)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        .rideNavigationGlassSurface(cornerRadius: Constants.popoverCornerRadius)
    }

    private func styleButton(title: String, systemImage: String, id: String) -> some View {
        Button {
            onSelect(id)
        } label: {
            HStack(spacing: Constants.rowSpacing) {
                Label(title, systemImage: systemImage)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(
                        horizontal: false,
                        vertical: dynamicTypeSize.isAccessibilitySize
                    )
                Spacer(minLength: Constants.rowSpacing)
                if selectedStyleID == id {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: Constants.rowHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
    }

    private enum Constants {
        static let focusStyleID = "focus"
        static let popoverWidth: CGFloat = 220
        static let popoverPadding: CGFloat = 16
        static let popoverCornerRadius: CGFloat = 20
        static let rowHeight: CGFloat = 40
        static let rowSpacing: CGFloat = 10
    }
}
