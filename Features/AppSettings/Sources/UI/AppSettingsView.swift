import DesignSystem
import SettingsDomain
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
                    Text("Bike").tag(SpeedSource.motorcycle.rawValue)
                    Text("GPS").tag(SpeedSource.gps.rawValue)
                    Text("Hybrid").tag(SpeedSource.hybrid.rawValue)
                }
                .pickerStyle(.segmented)

                Text(speedSourceDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if viewModel.settings.speedSource.usesDeviceLocation {
                    LocationPermissionRow(
                        status: viewModel.locationAuthorizationStatus,
                        onRequestAccess: viewModel.requestLocationAccess
                    )
                }
            }
            #endif

            Section("Units") {
                Picker("Measurement system", selection: measurementSystemBinding) {
                    Text("System").tag(MeasurementSystem.system.rawValue)
                    Text("Metric").tag(MeasurementSystem.metric.rawValue)
                    Text("Imperial").tag(MeasurementSystem.imperial.rawValue)
                }
                .pickerStyle(selectionPickerStyle)
            }

            Section("Battery") {
                Picker("Pack capacity", selection: batteryPackCapacityBinding) {
                    ForEach(BatteryPackCapacity.allCases, id: \.rawValue) { capacity in
                        Text(capacity.displayName).tag(capacity.rawValue)
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
            get: { viewModel.settings.speedSource.rawValue },
            set: { rawValue in
                guard let source = SpeedSource(rawValue: rawValue) else { return }
                viewModel.selectSpeedSource(source)
            }
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
            get: { viewModel.settings.measurementSystem.rawValue },
            set: { rawValue in
                guard let system = MeasurementSystem(rawValue: rawValue) else { return }
                viewModel.selectMeasurementSystem(system)
            }
        )
    }

    private var batteryPackCapacityBinding: Binding<String> {
        .init(
            get: { viewModel.settings.batteryPackCapacity.rawValue },
            set: { rawValue in
                guard let capacity = BatteryPackCapacity(rawValue: rawValue) else { return }
                viewModel.selectBatteryPackCapacity(capacity)
            }
        )
    }

    private var speedSourceDescription: String {
        switch viewModel.settings.speedSource {
        case .motorcycle: "Uses speed reported by the motorcycle."
        case .gps: "Uses phone GPS when a recent, accurate reading is available."
        case .hybrid: "Uses GPS when available and falls back to motorcycle telemetry."
        }
    }
}
