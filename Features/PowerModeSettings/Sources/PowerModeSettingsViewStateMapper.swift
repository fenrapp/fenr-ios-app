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
                accessibilityLabel: name.map { "Map \(mapNumber), \($0)" } ?? "Map \(mapNumber)",
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
                isBaseControlReady: input.isBaseControlReady && !input.isApplyingControl,
                isTractionControlReady: input.isTractionControlReady
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
                title: "Power",
                value: configuration?.horsepower.map(Double.init),
                unit: "HP",
                minimum: 10,
                maximum: powerMaximum,
                step: 1,
                isEnabled: isBaseControlReady
            )),
            adjustment(.init(
                id: .regeneration,
                title: "Regenerative braking",
                value: configuration?.regenerativeBrakingPercent,
                unit: "%",
                minimum: -100,
                maximum: 100,
                step: 1,
                isEnabled: isBaseControlReady
            )),
            adjustment(.init(
                id: .powerTraction,
                title: "Traction control",
                value: configuration?.powerTractionPercent,
                unit: "%",
                minimum: 0,
                maximum: 100,
                step: 1,
                isEnabled: isTractionControlReady
            )),
            adjustment(.init(
                id: .brakingTraction,
                title: "Regen traction control",
                value: configuration?.brakingTractionPercent,
                unit: "%",
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
        guard let value else { return "Unavailable" }
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
            return "Alpha capability detected · 80 HP"
        }
        if declaredTier == .alpha {
            return "Alpha expected · verification pending"
        }
        return "Standard baseline · 60 HP"
    }

    private func status(
        configuration: BikePowerModeConfiguration?,
        isTractionControlReady: Bool,
        input: PowerModeSettingsMappingInput
    ) -> (text: String, isError: Bool) {
        if input.isRefreshing {
            return ("Reading power modes", false)
        }
        if let refreshError = input.refreshError {
            return (refreshError, true)
        }
        if let controlError = input.controlError {
            return (controlError, true)
        }
        if input.isApplyingControl {
            return ("Applying and verifying map", false)
        }
        if input.isPreparingControl {
            return ("Verifying map write safety", false)
        }
        guard configuration?.hasBaseConfiguration == true else {
            return ("Waiting for confirmed map data", false)
        }
        if let controlMessage = input.controlMessage {
            return (controlMessage, false)
        }
        if input.isBaseControlReady {
            let text = isTractionControlReady
                ? "All map controls ready"
                : "Power and regeneration controls ready"
            return (text, false)
        }
        return ("Bike write verification required", false)
    }

    private func connectionText(_ state: ConnectionState) -> String {
        switch state {
        case .receivingTelemetry: "Bike connected"
        case .authenticated, .subscribed: "Bike authenticated"
        case .scanning, .connecting, .discovering, .authenticating, .reconnecting: "Connecting to bike"
        case .bluetoothPoweredOff: "Bluetooth is off"
        case .bluetoothUnauthorized: "Bluetooth access is required"
        case .bluetoothUnavailable: "Bluetooth is unavailable"
        case .pairingResetRequired(let message), .failed(let message): message
        case .disconnected(let reason): reason ?? "Bike disconnected"
        case .idle: "Bike unavailable"
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
