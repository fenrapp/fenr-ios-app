import SwiftUI

struct RideNavigationMapSourceMenu: View {
    let sources: [MapSourceDescriptor]
    let selectedStyleID: String
    let allowsFocus: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
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
        } label: {
            RideNavigationMapControlLabel(systemImage: "map.fill")
        }
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel("Map style")
    }

    private func styleButton(title: String, systemImage: String, id: String) -> some View {
        Button(
            action: { onSelect(id) },
            label: { Label(title, systemImage: selectedStyleID == id ? "checkmark" : systemImage) }
        )
    }

    private enum Constants {
        static let focusStyleID = "focus"
    }
}
