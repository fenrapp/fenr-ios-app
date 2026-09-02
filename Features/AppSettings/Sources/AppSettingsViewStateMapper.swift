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
        verificationMessage: String? = nil,
        verificationMessageIsError: Bool = false
    ) -> AppSettingsViewState {
        return .init(
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
            dashboardProgressBarMode: .init(
                selection: .init(
                    selectedID: settings.dashboardProgressBarMode.rawValue,
                    options: DashboardProgressBarMode.allCases.map {
                        .init(id: $0.rawValue, title: dashboardProgressBarModeTitle($0))
                    }
                ),
                description: dashboardProgressBarModeDescription(settings.dashboardProgressBarMode)
            ),
            dashboardBatteryIndicatorMode: .init(
                selectedID: settings.dashboardBatteryIndicatorMode.rawValue,
                options: DashboardBatteryIndicatorMode.allCases.map {
                    .init(id: $0.rawValue, title: dashboardBatteryIndicatorModeTitle($0))
                }
            ),
            dashboardDeviceBatteryDisplayMode: .init(
                selectedID: settings.dashboardDeviceBatteryDisplayMode.rawValue,
                options: DashboardDeviceBatteryDisplayMode.allCases.map {
                    .init(id: $0.rawValue, title: dashboardDeviceBatteryDisplayModeTitle($0))
                }
            ),
            showsDashboardTemperatures: settings.showsDashboardTemperatures,
            measurementSystem: .init(
                selectedID: settings.measurementSystem.rawValue,
                options: MeasurementSystem.allCases.map {
                    .init(id: $0.rawValue, title: measurementSystemTitle($0))
                }
            ),
            batteryCapacity: .init(
                selectedID: settings.batteryPackCapacity(forVIN: profile?.vin).rawValue,
                options: BatteryPackCapacity.allCases.map {
                    .init(id: $0.rawValue, title: batteryPackCapacityTitle($0))
                }
            ),
            powerTier: powerTier(
                profile: profile,
                connection: connection,
                isVerifying: isVerifying,
                verificationMessage: verificationMessage,
                verificationMessageIsError: verificationMessageIsError
            ),
            rideDisplay: .init(detail: rideDisplayDetail(settings: settings)),
            dashboardCards: .init(detail: dashboardCardsDetail(settings.dashboardCardConfiguration)),
            powerModes: powerModes(settings: settings, profile: profile)
        )
    }

    private func powerModes(
        settings: AppSettings,
        profile: BikeProfile?
    ) -> SettingsNavigationSummaryViewData {
        let count = settings.powerModeNames(forVIN: profile?.vin).count
        let detail = switch count {
        case 0: "5 maps configured"
        case 1: "5 maps · 1 custom name"
        default: "5 maps · \(count) custom names"
        }
        return .init(detail: detail)
    }

    private func rideDisplayDetail(settings: AppSettings) -> String {
        let progress = dashboardProgressBarModeTitle(settings.dashboardProgressBarMode)
        let speed = speedSourceTitle(settings.speedSource)
        return "\(progress) · \(speed)"
    }

    private func dashboardCardsDetail(_ configuration: DashboardCardConfiguration) -> String {
        let visibleCount = configuration.sections.filter(\.isVisible).count
        return "\(visibleCount) visible"
    }

    private func powerTier(
        profile: BikeProfile?,
        connection: BikeConnection,
        isVerifying: Bool,
        verificationMessage: String?,
        verificationMessageIsError: Bool
    ) -> PowerTierSettingsViewState {
        let declared = profile?.declaredPowerTier ?? .standard
        let evidence = profile?.alphaEvidence ?? []
        let status: String
        if !evidence.isEmpty, declared == .standard {
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
            navigationDetail: powerTierNavigationDetail(
                declared: declared,
                hasEvidence: !evidence.isEmpty
            ),
            status: status,
            evidence: evidenceDescription(profile: profile),
            verificationMessage: verificationMessage,
            verificationMessageIsError: verificationMessageIsError,
            isVerifyEnabled: isAuthenticated(connection.state) && !isVerifying,
            isVerifying: isVerifying
        )
    }

    private func powerTierNavigationDetail(
        declared: BikeDeclaredPowerTier,
        hasEvidence: Bool
    ) -> String {
        if hasEvidence, declared == .standard { return "Model mismatch" }
        if hasEvidence { return "Alpha detected" }
        return declared == .alpha ? "Alpha · Unverified" : "Standard"
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

    private func dashboardProgressBarModeTitle(_ mode: DashboardProgressBarMode) -> String {
        switch mode {
        case .energy: "Energy"
        case .speed: "Speed"
        case .hidden: "Hidden"
        }
    }

    private func dashboardProgressBarModeDescription(_ mode: DashboardProgressBarMode) -> String {
        switch mode {
        case .energy: "Regeneration fills left from the center; consumption fills right."
        case .speed: "Fills from left to right as speed increases."
        case .hidden: "Hides the progress bar from the ride dashboard."
        }
    }

    private func dashboardBatteryIndicatorModeTitle(_ mode: DashboardBatteryIndicatorMode) -> String {
        switch mode {
        case .percentage: "Percentage"
        case .estimatedRange: "Estimated range"
        }
    }

    private func dashboardDeviceBatteryDisplayModeTitle(_ mode: DashboardDeviceBatteryDisplayMode) -> String {
        switch mode {
        case .iconAndText: "Icon and percentage"
        case .textOnly: "Percentage only"
        case .iconOnly: "Icon only"
        case .hidden: "Hidden"
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

    private func batteryPackCapacityTitle(_ capacity: BatteryPackCapacity) -> String {
        switch capacity {
        case .sixPointEightKilowattHours: "6.8 kWh"
        case .sevenPointTwoKilowattHours: "7.2 kWh"
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
