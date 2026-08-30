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
        .accessibilityLabel("Map style")
        .accessibilityValue(selectedStyleTitle)
    }

    private var selectedStyleTitle: String {
        if selectedStyleID == Constants.focusStyleID { return "Focus" }
        return sources.first(where: { $0.id == selectedStyleID })?.title ?? "Map"
    }

    private enum Constants {
        static let focusStyleID = "focus"
    }
}

struct RideNavigationMapSourcePicker: View {
    let sources: [MapSourceDescriptor]
    let selectedStyleID: String
    let allowsFocus: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            Text("Map Style")
                .font(.headline)
            if allowsFocus {
                styleButton(
                    title: "Focus",
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
        .frame(width: Constants.popoverWidth)
        .rideNavigationGlassSurface(cornerRadius: Constants.popoverCornerRadius)
    }

    private func styleButton(title: String, systemImage: String, id: String) -> some View {
        Button {
            onSelect(id)
        } label: {
            HStack(spacing: Constants.rowSpacing) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: Constants.rowSpacing)
                if selectedStyleID == id {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: Constants.rowHeight, alignment: .leading)
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
