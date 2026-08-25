import EnvironmentDomain
import SettingsDomain

public struct AppSettingsViewStateMapper: Sendable {
    public init() {}

    public func map(
        settings: AppSettings,
        locationAuthorizationStatus: LocationAuthorizationStatus
    ) -> AppSettingsViewState {
        .init(
            speedSource: .init(
                selection: .init(
                    selectedID: settings.speedSource.rawValue,
                    options: SpeedSource.allCases.map {
                        .init(id: $0.rawValue, title: speedSourceTitle($0))
                    }
                ),
                description: speedSourceDescription(settings.speedSource),
                locationPermission: settings.speedSource.usesDeviceLocation
                    ? locationPermission(locationAuthorizationStatus)
                    : nil
            ),
            measurementSystem: .init(
                selectedID: settings.measurementSystem.rawValue,
                options: MeasurementSystem.allCases.map {
                    .init(id: $0.rawValue, title: measurementSystemTitle($0))
                }
            ),
            batteryCapacity: .init(
                selectedID: settings.batteryPackCapacity.rawValue,
                options: BatteryPackCapacity.allCases.map {
                    .init(id: $0.rawValue, title: $0.displayName)
                }
            )
        )
    }

    private func speedSourceTitle(_ source: SpeedSource) -> String {
        switch source {
        case .motorcycle: "Bike"
        case .gps: "GPS"
        case .hybrid: "Hybrid"
        }
    }

    private func speedSourceDescription(_ source: SpeedSource) -> String {
        switch source {
        case .motorcycle: "Uses speed reported by the motorcycle."
        case .gps: "Uses phone GPS when a recent, accurate reading is available."
        case .hybrid: "Uses GPS when available and falls back to motorcycle telemetry."
        }
    }

    private func measurementSystemTitle(_ system: MeasurementSystem) -> String {
        switch system {
        case .system: "System"
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    private func locationPermission(_ status: LocationAuthorizationStatus) -> LocationPermissionViewState {
        switch status {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        }
    }
}
