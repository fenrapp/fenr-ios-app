import DesignSystem
import SwiftUI

public struct AppSettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel
    private let onOpenTelemetry: () -> Void

    public init(
        viewModel: AppSettingsViewModel,
        onOpenTelemetry: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onOpenTelemetry = onOpenTelemetry
    }

    public var body: some View {
        Form {
            #if os(iOS)
            Section("Ride dashboard") {
                Picker("Speed source", selection: speedSourceBinding) {
                    ForEach(viewModel.viewState.speedSource.selection.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.viewState.speedSource.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let locationPermission = viewModel.viewState.speedSource.locationPermission {
                    LocationPermissionRow(
                        status: locationPermission,
                        onRequestAccess: viewModel.requestLocationAccess
                    )
                }
            }
            #endif

            Section("Units") {
                Picker("Measurement system", selection: measurementSystemBinding) {
                    ForEach(viewModel.viewState.measurementSystem.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(selectionPickerStyle)
            }

            Section("Battery") {
                Picker("Pack capacity", selection: batteryPackCapacityBinding) {
                    ForEach(viewModel.viewState.batteryCapacity.options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(selectionPickerStyle)

                Text("Used to estimate the remaining charging time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            #if os(iOS)
            Section("Diagnostics") {
                TelemetryActionRow(action: onOpenTelemetry)
            }
            #endif
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var speedSourceBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.speedSource.selection.selectedID },
            set: { viewModel.selectSpeedSource(id: $0) }
        )
    }

    private var selectionPickerStyle: some PickerStyle {
        #if os(watchOS)
        NavigationLinkPickerStyle()
        #else
        SegmentedPickerStyle()
        #endif
    }

    private var measurementSystemBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.measurementSystem.selectedID },
            set: { viewModel.selectMeasurementSystem(id: $0) }
        )
    }

    private var batteryPackCapacityBinding: Binding<String> {
        .init(
            get: { viewModel.viewState.batteryCapacity.selectedID },
            set: { viewModel.selectBatteryPackCapacity(id: $0) }
        )
    }

}
