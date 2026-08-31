import SwiftUI

struct BatterySettingsSection: View {
    let dashboardIndicatorMode: AppSettingsSelectionViewState
    let capacity: AppSettingsSelectionViewState
    let onSelectDashboardIndicatorMode: (String) -> Void
    let onSelectCapacity: (String) -> Void

    var body: some View {
        Section("Battery") {
            #if os(iOS)
            Picker("Dashboard display", selection: dashboardIndicatorModeBinding) {
                ForEach(dashboardIndicatorMode.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            Text("Falls back to battery percentage until an estimated range is available.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #endif

            Picker("Pack capacity", selection: capacityBinding) {
                ForEach(capacity.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(selectionPickerStyle)

            Text("Used to estimate the remaining charging time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var dashboardIndicatorModeBinding: Binding<String> {
        .init(
            get: { dashboardIndicatorMode.selectedID },
            set: { onSelectDashboardIndicatorMode($0) }
        )
    }

    private var capacityBinding: Binding<String> {
        .init(
            get: { capacity.selectedID },
            set: { onSelectCapacity($0) }
        )
    }

    private var selectionPickerStyle: some PickerStyle {
        #if os(watchOS)
        NavigationLinkPickerStyle()
        #else
        SegmentedPickerStyle()
        #endif
    }
}
