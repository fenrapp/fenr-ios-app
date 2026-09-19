import DesignSystem
import SwiftUI

struct RideNavigationMapSourcePicker: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let sources: [MapSourceDescriptor]
    let selectedStyleID: String
    let allowsFocus: Bool
    let mode: RideNavigationMapModeState
    var coverageNotice: String?
    var onOfflineMaps: (() -> Void)?
    let onSelect: (String) -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            content.fixedSize(horizontal: false, vertical: true)
            ScrollView { content }.scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : Constants.popoverWidth)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            Text(.rideNavigationMapModeTitle).font(.headline)
            Picker(.rideNavigationMapModeTitle, selection: Binding(get: { mode.selectedID }, set: { onSelect($0) })) {
                ForEach(mode.choices) { choice in
                    Text(verbatim: choice.title).tag(choice.id)
                }
            }
            .pickerStyle(.segmented)
            Text(verbatim: mode.detail).font(.caption).foregroundStyle(.secondary)
            Divider()
            Text(.rideNavigationMapStyleTitle).font(.headline)
            if allowsFocus {
                styleButton(
                    title: String(localized: .rideNavigationMapStyleFocus),
                    systemImage: "location.north.line.fill", id: "focus"
                )
            }
            ForEach(sources) { source in
                styleButton(
                    title: source.title,
                    systemImage: source.id == MapSourceDescriptor.appleHybrid.id ? "globe.americas.fill" : "map.fill",
                    id: source.id
                )
            }
            if let coverageNotice {
                Text(verbatim: coverageNotice).font(.caption).foregroundStyle(.secondary)
            }
            if let onOfflineMaps {
                Divider()
                Button(action: onOfflineMaps) { Label(.offlineMapsTitle, systemImage: "arrow.down.circle") }
                    .font(.subheadline).frame(minHeight: Constants.rowHeight)
            }
        }
        .padding(DesignSpace.medium)
    }

    private func styleButton(title: String, systemImage: String, id: String) -> some View {
        Button { onSelect(id) } label: {
            HStack(spacing: DesignSpace.small) {
                Label(title, systemImage: systemImage)
                Spacer(minLength: DesignSpace.small)
                if selectedStyleID == id { Image(systemName: "checkmark").fontWeight(.semibold) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: Constants.rowHeight, alignment: .leading)
    }

    private enum Constants {
        static let popoverWidth = 280.0
        static let cornerRadius = 20.0
        static let rowHeight = 40.0
    }
}
