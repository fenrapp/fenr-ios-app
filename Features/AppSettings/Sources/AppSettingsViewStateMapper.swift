import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain

public struct AppSettingsViewStateMapper: Sendable {
    public init() {}

    public func map(
        settings: AppSettings,
        locationAuthorizationStatus: LocationAuthorizationStatus,
        profile: BikeProfile? = nil,
        connection: BikeConnection = .init(),
        isVerifying: Bool = false,
        verificationMessage: LocalizedStringResource? = nil,
        verificationMessageIsError: Bool = false
    ) -> AppSettingsViewState {
        return .init(
            speedSource: speedSource(settings.speedSource, locationAuthorizationStatus),
            dashboardProgressBarMode: .init(
                selection: .init(
                    selectedID: settings.dashboardProgressBarMode.rawValue,
                    options: DashboardProgressBarMode.allCases.map {
                        .init(id: $0.rawValue, title: dashboardProgressBarModeTitle($0))
                    }
                ),
                description: dashboardProgressBarModeDescription(settings.dashboardProgressBarMode),
                thickness: settings.dashboardProgressBarMode == .hidden ? nil : progressBarThickness(settings)
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
            dashboardTemperatureDisplayMode: temperatureDisplayMode(settings.dashboardTemperatureDisplayMode),
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
            isBikeModelSelectionVisible: profile?.alphaEvidence.isEmpty != false,
            rideDisplay: .init(detail: rideDisplayDetail(settings: settings)),
            dashboardCards: .init(detail: dashboardCardsDetail(settings.dashboardCardConfiguration)),
            powerModes: powerModes(settings: settings, profile: profile),
            navigation: .init(detail: .appSettingsNavigationDetail),
            navigationSettings: navigationSettings(settings.rideNavigation),
            liveActivities: liveActivities(settings.liveActivities)
        )
    }

    private func powerModes(
        settings: AppSettings,
        profile: BikeProfile?
    ) -> SettingsNavigationSummaryViewData {
        let count = settings.powerModeNames(forVIN: profile?.vin).count
        let detail: LocalizedStringResource = switch count {
        case 0: .appSettingsPowerModesConfigured
        default: .appSettingsPowerModesCustomNames(count)
        }
        return .init(detail: detail)
    }

    private func rideDisplayDetail(settings: AppSettings) -> LocalizedStringResource {
        let progress = String(localized: dashboardProgressBarModeTitle(settings.dashboardProgressBarMode))
        let speed = String(localized: speedSourceTitle(settings.speedSource))
        return .appSettingsRideDisplaySummary(progress, speed)
    }

    private func dashboardCardsDetail(_ configuration: DashboardCardConfiguration) -> LocalizedStringResource {
        let visibleCount = configuration.sections.filter(\.isVisible).count
        return .appSettingsDashboardCardsVisibleCount(visibleCount)
    }

    private func powerTier(
        profile: BikeProfile?,
        connection: BikeConnection,
        isVerifying: Bool,
        verificationMessage: LocalizedStringResource?,
        verificationMessageIsError: Bool
    ) -> PowerTierSettingsViewState {
        let declared = profile?.declaredPowerTier ?? .standard
        let evidence = profile?.alphaEvidence ?? []
        let status: LocalizedStringResource
        if !evidence.isEmpty, declared == .standard {
            status = .appSettingsPowerTierMismatchStatus
        } else if !evidence.isEmpty {
            status = .appSettingsPowerTierAlphaDetected
        } else if declared == .alpha {
            status = .appSettingsPowerTierPendingVerification
        } else {
            status = .appSettingsPowerTierStandardMaximum
        }
        return .init(
            selection: .init(
                selectedID: declared.rawValue,
                options: BikeDeclaredPowerTier.allCases.map {
                    .init(
                        id: $0.rawValue,
                        title: $0 == .standard
                            ? .appSettingsPowerTierStandard
                            : .appSettingsPowerTierAlpha
                    )
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
    ) -> LocalizedStringResource {
        if hasEvidence, declared == .standard { return .appSettingsPowerTierModelMismatch }
        if hasEvidence { return .appSettingsPowerTierAlphaDetected }
        return declared == .alpha
            ? .appSettingsPowerTierAlphaUnverified
            : .appSettingsPowerTierStandard
    }

    private func evidenceDescription(profile: BikeProfile?) -> LocalizedStringResource? {
        guard let profile, !profile.alphaEvidence.isEmpty else { return nil }
        var parts: [String] = []
        if profile.alphaEvidence.contains(.powerAboveStandard) {
            parts.append(String(localized: .appSettingsPowerTierEvidencePowerAboveStandard))
        }
        if profile.alphaEvidence.contains(.tractionControlConfigured) {
            parts.append(String(localized: .appSettingsPowerTierEvidenceTractionControl))
        }
        if let date = profile.alphaDetectedAt {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        return .appSettingsPowerTierEvidenceSummary(parts.joined(separator: " · "))
    }

    private func isAuthenticated(_ state: ConnectionState) -> Bool {
        switch state {
        case .authenticated, .subscribed, .receivingTelemetry: true
        default: false
        }
    }

    func speedSourceTitle(_ source: SpeedSource) -> LocalizedStringResource {
        switch source {
        case .motorcycle: .appSettingsSpeedSourceBike
        case .gps: .appSettingsSpeedSourceGps
        case .hybrid: .appSettingsSpeedSourceHybrid
        }
    }

    private func dashboardProgressBarModeTitle(_ mode: DashboardProgressBarMode) -> LocalizedStringResource {
        switch mode {
        case .energy: .appSettingsProgressBarEnergy
        case .speed: .appSettingsProgressBarSpeed
        case .hidden: .appSettingsCommonHidden
        }
    }

    private func dashboardProgressBarModeDescription(_ mode: DashboardProgressBarMode) -> LocalizedStringResource {
        switch mode {
        case .energy: .appSettingsProgressBarEnergyDescription
        case .speed: .appSettingsProgressBarSpeedDescription
        case .hidden: .appSettingsProgressBarHiddenDescription
        }
    }

    private func dashboardBatteryIndicatorModeTitle(_ mode: DashboardBatteryIndicatorMode) -> LocalizedStringResource {
        switch mode {
        case .percentage: .appSettingsBatteryIndicatorPercentage
        case .estimatedRange: .appSettingsBatteryIndicatorEstimatedRange
        }
    }

    private func dashboardDeviceBatteryDisplayModeTitle(
        _ mode: DashboardDeviceBatteryDisplayMode
    ) -> LocalizedStringResource {
        switch mode {
        case .iconAndText: .appSettingsDeviceBatteryIconAndPercentage
        case .textOnly: .appSettingsDeviceBatteryPercentageOnly
        case .iconOnly: .appSettingsDeviceBatteryIconOnly
        case .hidden: .appSettingsCommonHidden
        }
    }

    private func dashboardTemperatureDisplayModeTitle(
        _ mode: DashboardTemperatureDisplayMode
    ) -> LocalizedStringResource {
        switch mode {
        case .off: .appSettingsTemperaturesOff
        case .battery: .appSettingsTemperaturesBattery
        case .inverter: .appSettingsTemperaturesInverter
        case .both: .appSettingsTemperaturesBoth
        }
    }

    private func temperatureDisplayMode(
        _ mode: DashboardTemperatureDisplayMode
    ) -> AppSettingsSelectionViewState {
        .init(
            selectedID: mode.rawValue,
            options: DashboardTemperatureDisplayMode.allCases.map {
                .init(id: $0.rawValue, title: dashboardTemperatureDisplayModeTitle($0))
            }
        )
    }

    func speedSourceDescription(_ source: SpeedSource) -> LocalizedStringResource {
        switch source {
        case .motorcycle: .appSettingsSpeedSourceBikeDescription
        case .gps: .appSettingsSpeedSourceGpsDescription
        case .hybrid: .appSettingsSpeedSourceHybridDescription
        }
    }

    private func measurementSystemTitle(_ system: MeasurementSystem) -> LocalizedStringResource {
        switch system {
        case .system: .appSettingsMeasurementSystem
        case .metric: .appSettingsMeasurementMetric
        case .imperial: .appSettingsMeasurementImperial
        }
    }

    private func batteryPackCapacityTitle(_ capacity: BatteryPackCapacity) -> LocalizedStringResource {
        switch capacity {
        case .sixPointEightKilowattHours: .appSettingsBatteryCapacitySixPointEight
        case .sevenPointTwoKilowattHours: .appSettingsBatteryCapacitySevenPointTwo
        }
    }

    func locationPermission(_ status: LocationAuthorizationStatus) -> LocationPermissionViewState {
        switch status {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        }
    }
}
