import DesignSystem
import SwiftUI

struct RideNavigationMapSourceMenu: View {
    let sources: [MapSourceDescriptor]
    var mode: RideNavigationMapModeState = .normal
    let selectedStyleID: String
    let allowsFocus: Bool
    let isPresented: Bool
    let onPresentationChange: (Bool) -> Void

    var body: some View {
        Button {
            onPresentationChange(!isPresented)
        } label: {
            RideNavigationMapControlLabel(systemImage: mode.symbol)
                .foregroundStyle(mode.isEmphasized ? DesignColor.accent : .primary)
        }
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel(.rideNavigationMapStyleAccessibility)
        .accessibilityValue(Text(verbatim: [mode.title, selectedStyleTitle].formatted(.list(type: .and))))
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
