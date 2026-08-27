import BikeDomain
import EnvironmentDomain
import SettingsDomain

public struct AppSettingsViewStateMapper: Sendable {
    public init() {}

    public func map(
        settings: AppSettings,
        locationAuthorizationStatus: LocationAuthorizationStatus,
        profile: BikeProfile? = nil,
        connection: BikeConnection = .init(),
        isVerifying: Bool = false,
        verificationMessage: String? = nil
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
                selectedID: settings.batteryPackCapacity(forVIN: profile?.vin).rawValue,
                options: BatteryPackCapacity.allCases.map {
                    .init(id: $0.rawValue, title: $0.displayName)
                }
            ),
            powerTier: powerTier(
                profile: profile,
                connection: connection,
                isVerifying: isVerifying,
                verificationMessage: verificationMessage
            )
        )
    }

    private func powerTier(
        profile: BikeProfile?,
        connection: BikeConnection,
        isVerifying: Bool,
        verificationMessage: String?
    ) -> PowerTierSettingsViewState {
        let declared = profile?.declaredPowerTier ?? .standard
        let evidence = profile?.alphaEvidence ?? []
        let status: String
        if let verificationMessage {
            status = verificationMessage
        } else if !evidence.isEmpty, declared == .standard {
            status = "Tier mismatch: bike reports Alpha evidence"
        } else if !evidence.isEmpty {
            status = "Alpha detected"
        } else if declared == .alpha {
            status = "Pending bike verification"
        } else {
            status = "Standard baseline · 60 HP max"
        }
        return .init(
            selection: .init(
                selectedID: declared.rawValue,
                options: BikeDeclaredPowerTier.allCases.map {
                    .init(id: $0.rawValue, title: $0 == .standard ? "Standard" : "Alpha")
                }
            ),
            status: status,
            evidence: evidenceDescription(profile: profile),
            isVerifyEnabled: isAuthenticated(connection.state) && !isVerifying,
            isVerifying: isVerifying
        )
    }

    private func evidenceDescription(profile: BikeProfile?) -> String? {
        guard let profile, !profile.alphaEvidence.isEmpty else { return nil }
        var parts: [String] = []
        if profile.alphaEvidence.contains(.powerAboveStandard) { parts.append("Power above 60 HP") }
        if profile.alphaEvidence.contains(.tractionControlConfigured) { parts.append("TC configured") }
        if let date = profile.alphaDetectedAt {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }

    private func isAuthenticated(_ state: ConnectionState) -> Bool {
        switch state {
        case .authenticated, .subscribed, .receivingTelemetry: true
        default: false
        }
    }

    private func speedSourceTitle(_ source: SpeedSource) -> String {
        switch source {
        case .motorcycle: "Bike"
        case .gps: "GPS"
        case .hybrid: "GPS+"
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
