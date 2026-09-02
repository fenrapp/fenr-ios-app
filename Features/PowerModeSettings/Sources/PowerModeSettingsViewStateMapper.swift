import BikeDomain
import Foundation
import SettingsDomain

public struct PowerModeSettingsViewStateMapper: Sendable {
    private let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    func map(_ input: PowerModeSettingsMappingInput) -> PowerModeSettingsViewState {
        let telemetry = input.telemetry
        let profile = input.profile
        let selectedMapIndex = input.selectedMapIndex
        let names = input.settings.powerModeNames(forVIN: profile?.vin)
        let configuration = telemetry.powerModeConfigurations[selectedMapIndex]
        let powerMaximum = maximumHorsepower(
            detectedTier: telemetry.detectedPowerTier,
            declaredTier: profile?.declaredPowerTier
        )
        let isTractionConfigurationSupported = isSupportedTractionConfiguration(configuration)
        let maps = (0 ... 4).map { mapIndex in
            let mapNumber = mapIndex + 1
            let name = names[mapIndex]?.value
            return PowerModeMapViewData(
                id: mapIndex,
                title: name ?? String(mapNumber),
                accessibilityLabel: name.map {
                    String(localized: .powerModeSettingsNamedMapAccessibility(mapNumber, $0))
                } ?? String(localized: .powerModeSettingsMapAccessibility(mapNumber)),
                isSelected: mapIndex == selectedMapIndex
            )
        }
        let status = status(
            configuration: configuration,
            isTractionControlReady: input.isTractionControlReady
                && isTractionConfigurationSupported,
            input: input
        )
        return PowerModeSettingsViewState(
            maps: maps,
            selectedMapIndex: selectedMapIndex,
            currentName: names[selectedMapIndex]?.value ?? "",
            maximumNameLength: PowerModeName.maximumLength,
            canEditName: profile != nil,
            nameError: input.nameError,
            connectionText: connectionText(input.connection.state),
            capabilityText: capabilityText(
                detectedTier: telemetry.detectedPowerTier,
                declaredTier: profile?.declaredPowerTier
            ),
            statusText: status.text,
            statusIsError: status.isError,
            canRefresh: input.isStarted
                && isAuthenticated(input.connection.state)
                && !input.isRefreshing
                && !input.isPreparingControl
                && !input.isApplyingControl,
            adjustments: adjustments(
                configuration: configuration,
                powerMaximum: powerMaximum,
                isBaseControlReady: input.isCanonicalTelemetryAvailable
                    && input.isBaseControlReady
                    && !input.isApplyingControl,
                isTractionControlReady: input.isTractionControlReady
                    && input.isCanonicalTelemetryAvailable
                    && isTractionConfigurationSupported
                    && !input.isApplyingControl
            )
        )
    }

    private func adjustments(
        configuration: BikePowerModeConfiguration?,
        powerMaximum: Double,
        isBaseControlReady: Bool,
        isTractionControlReady: Bool
    ) -> [PowerModeAdjustmentViewState] {
        [
            adjustment(.init(
                id: .power,
                title: String(localized: .powerModeSettingsPowerAdjustment),
                value: configuration?.horsepower.map(Double.init),
                unit: String(localized: .powerModeSettingsHorsepowerUnit),
                minimum: 10,
                maximum: powerMaximum,
                step: 1,
                isEnabled: isBaseControlReady
            )),
            adjustment(.init(
                id: .regeneration,
                title: String(localized: .powerModeSettingsRegenerationAdjustment),
                value: configuration?.regenerativeBrakingPercent,
                unit: String(localized: .powerModeSettingsPercentUnit),
                minimum: -100,
                maximum: 100,
                step: 1,
                isEnabled: isBaseControlReady
            )),
            adjustment(.init(
                id: .powerTraction,
                title: String(localized: .powerModeSettingsTractionAdjustment),
                value: configuration?.powerTractionPercent,
                unit: String(localized: .powerModeSettingsPercentUnit),
                minimum: 0,
                maximum: 100,
                step: 1,
                isEnabled: isTractionControlReady
            )),
            adjustment(.init(
                id: .brakingTraction,
                title: String(localized: .powerModeSettingsRegenTractionAdjustment),
                value: configuration?.brakingTractionPercent,
                unit: String(localized: .powerModeSettingsPercentUnit),
                minimum: 0,
                maximum: 100,
                step: 1,
                isEnabled: isTractionControlReady
            ))
        ]
    }

    private func adjustment(_ input: AdjustmentInput) -> PowerModeAdjustmentViewState {
        .init(
            id: input.id,
            title: input.title,
            value: input.value,
            valueText: formatted(input.value),
            unit: input.unit,
            minimum: input.minimum,
            maximum: input.maximum,
            step: input.step,
            isEnabled: input.isEnabled && input.value != nil,
            localeIdentifier: locale.identifier
        )
    }

    private struct AdjustmentInput {
        let id: PowerModeAdjustmentID
        let title: String
        let value: Double?
        let unit: String
        let minimum: Double
        let maximum: Double
        let step: Double
        let isEnabled: Bool
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return String(localized: .powerModeSettingsUnavailable) }
        return value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(0 ... 1))
        )
    }

    private func maximumHorsepower(
        detectedTier: BikeDetectedPowerTier,
        declaredTier: BikeDeclaredPowerTier?
    ) -> Double {
        if case .alpha = detectedTier { return 80 }
        return declaredTier == .alpha ? 80 : 60
    }

    private func capabilityText(
        detectedTier: BikeDetectedPowerTier,
        declaredTier: BikeDeclaredPowerTier?
    ) -> String {
        if case .alpha = detectedTier {
            return String(localized: .powerModeSettingsAlphaCapabilityDetected)
        }
        if declaredTier == .alpha {
            return String(localized: .powerModeSettingsAlphaVerificationPending)
        }
        return String(localized: .powerModeSettingsStandardBaseline)
    }

    private func status(
        configuration: BikePowerModeConfiguration?,
        isTractionControlReady: Bool,
        input: PowerModeSettingsMappingInput
    ) -> (text: String, isError: Bool) {
        if input.isRefreshing {
            return (String(localized: .powerModeSettingsReadingStatus), false)
        }
        if let refreshError = input.refreshError {
            return (refreshError, true)
        }
        if let controlError = input.controlError {
            return (controlError, true)
        }
        if input.isApplyingControl {
            return (String(localized: .powerModeSettingsApplyingStatus), false)
        }
        if input.isPreparingControl {
            return (String(localized: .powerModeSettingsVerifyingSafetyStatus), false)
        }
        guard configuration?.hasBaseConfiguration == true else {
            return (String(localized: .powerModeSettingsWaitingForMapDataStatus), false)
        }
        if let controlMessage = input.controlMessage {
            return (controlMessage, false)
        }
        if input.isBaseControlReady {
            let text = isTractionControlReady
                ? String(localized: .powerModeSettingsAllControlsReady)
                : String(localized: .powerModeSettingsBaseControlsReady)
            return (text, false)
        }
        return (String(localized: .powerModeSettingsWriteVerificationRequired), false)
    }

    private func connectionText(_ state: ConnectionState) -> String {
        switch state {
        case .receivingTelemetry: String(localized: .powerModeSettingsBikeConnected)
        case .authenticated, .subscribed: String(localized: .powerModeSettingsBikeAuthenticated)
        case .scanning, .connecting, .discovering, .authenticating, .reconnecting:
            String(localized: .powerModeSettingsConnectingToBike)
        case .bluetoothPoweredOff: String(localized: .powerModeSettingsBluetoothOff)
        case .bluetoothUnauthorized: String(localized: .powerModeSettingsBluetoothAccessRequired)
        case .bluetoothUnavailable: String(localized: .powerModeSettingsBluetoothUnavailable)
        case .pairingResetRequired: String(localized: .powerModeSettingsPairingResetRequired)
        case .failed: String(localized: .powerModeSettingsConnectionFailed)
        case .disconnected: String(localized: .powerModeSettingsBikeDisconnected)
        case .idle: String(localized: .powerModeSettingsBikeUnavailable)
        }
    }

    private func isAuthenticated(_ state: ConnectionState) -> Bool {
        switch state {
        case .authenticated, .subscribed, .receivingTelemetry: true
        default: false
        }
    }

    private func isSupportedTractionConfiguration(
        _ configuration: BikePowerModeConfiguration?
    ) -> Bool {
        guard let power = configuration?.powerTractionPercent,
              let braking = configuration?.brakingTractionPercent
        else {
            return false
        }
        return isSupportedTractionValue(power) && isSupportedTractionValue(braking)
    }

    private func isSupportedTractionValue(_ value: Double) -> Bool {
        value.isFinite && 0 ... 100 ~= value && value.rounded() == value
    }
}
