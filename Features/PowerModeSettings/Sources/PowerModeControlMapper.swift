import BikeDomain
import Foundation

struct PowerModeControlMapper: Sendable {
    let locale: Locale

    func controlData(for input: PowerModeSettingsMappingInput) -> PowerModeControlData {
        let configuration = input.telemetry.powerModeConfigurations[input.selectedMapIndex]
        let tractionSupported = isSupportedTractionConfiguration(configuration)
        let context = PowerModeAdjustmentMappingContext(
            configuration: configuration,
            powerMaximum: maximumHorsepower(
                detectedTier: input.telemetry.detectedPowerTier,
                declaredTier: input.profile?.declaredPowerTier
            ),
            isBaseControlReady: input.isCanonicalTelemetryAvailable
                && input.isBaseControlReady
                && !input.isApplyingControl,
            isTractionControlReady: input.isTractionControlReady
                && input.isCanonicalTelemetryAvailable
                && tractionSupported
                && !input.isApplyingControl,
            activeAdjustmentID: input.activeAdjustmentID,
            pendingValue: input.pendingAdjustmentValue,
            recentAdjustmentResult: input.recentAdjustmentResult
        )
        return .init(
            configuration: configuration,
            adjustments: adjustments(context),
            isTractionControlReady: input.isTractionControlReady && tractionSupported
        )
    }

    func controlGroups(
        from adjustments: [PowerModeAdjustmentViewState]
    ) -> [PowerModeControlGroupViewData] {
        [
            .init(
                id: .performance,
                title: String(localized: .powerModeSettingsPerformanceGroupTitle),
                detail: String(localized: .powerModeSettingsPerformanceGroupDetail),
                adjustments: Array(adjustments.prefix(2))
            ),
            .init(
                id: .traction,
                title: String(localized: .powerModeSettingsTractionGroupTitle),
                detail: String(localized: .powerModeSettingsTractionGroupDetail),
                adjustments: Array(adjustments.suffix(2))
            )
        ]
    }

    private func adjustments(
        _ context: PowerModeAdjustmentMappingContext
    ) -> [PowerModeAdjustmentViewState] {
        [
            adjustment(.init(
                id: .power,
                title: String(localized: .powerModeSettingsPowerAdjustment),
                value: displayedValue(
                    .power, confirmed: context.configuration?.horsepower.map(Double.init),
                    context: context
                ),
                unit: String(localized: .powerModeSettingsHorsepowerUnit),
                minimum: 10,
                maximum: context.powerMaximum,
                isEnabled: context.isBaseControlReady,
                feedback: feedback(for: .power, context: context)
            )),
            adjustment(.init(
                id: .regeneration,
                title: String(localized: .powerModeSettingsRegenerationAdjustment),
                value: displayedValue(
                    .regeneration, confirmed: supportedRegeneration(context.configuration?.regenerativeBrakingPercent),
                    context: context
                ),
                unit: String(localized: .powerModeSettingsPercentUnit),
                minimum: 0,
                maximum: 100,
                isEnabled: context.isBaseControlReady,
                feedback: feedback(for: .regeneration, context: context)
            )),
            adjustment(.init(
                id: .powerTraction,
                title: String(localized: .powerModeSettingsTractionAdjustment),
                value: displayedValue(
                    .powerTraction, confirmed: context.configuration?.powerTractionPercent,
                    context: context
                ),
                unit: String(localized: .powerModeSettingsPercentUnit),
                minimum: 0,
                maximum: 100,
                isEnabled: context.isTractionControlReady,
                feedback: feedback(for: .powerTraction, context: context)
            )),
            adjustment(.init(
                id: .brakingTraction,
                title: String(localized: .powerModeSettingsRegenTractionAdjustment),
                value: displayedValue(
                    .brakingTraction, confirmed: context.configuration?.brakingTractionPercent,
                    context: context
                ),
                unit: String(localized: .powerModeSettingsPercentUnit),
                minimum: 0,
                maximum: 100,
                isEnabled: context.isTractionControlReady,
                feedback: feedback(for: .brakingTraction, context: context)
            ))
        ]
    }

    private func displayedValue(
        _ id: PowerModeAdjustmentID, confirmed: Double?, context: PowerModeAdjustmentMappingContext
    ) -> Double? {
        context.activeAdjustmentID == id ? context.pendingValue ?? confirmed : confirmed
    }

    private func adjustment(
        _ input: PowerModeAdjustmentPresentationInput
    ) -> PowerModeAdjustmentViewState {
        .init(
            id: input.id,
            title: input.title,
            value: input.value,
            valueText: formatted(input.value),
            unit: input.unit,
            minimum: input.minimum,
            maximum: input.maximum,
            step: 1,
            isEnabled: input.isEnabled && input.value != nil,
            localeIdentifier: locale.identifier,
            feedback: input.feedback
        )
    }

    private func feedback(
        for id: PowerModeAdjustmentID,
        context: PowerModeAdjustmentMappingContext
    ) -> PowerModeControlFeedback {
        if context.activeAdjustmentID == id {
            return .init(
                state: .applying,
                title: String(localized: .powerModeSettingsAdjustmentApplying),
                emphasis: .informational,
                isActivity: true
            )
        }
        switch context.recentAdjustmentResult {
        case .confirmed(let resultID) where resultID == id:
            return .init(
                state: .confirmed,
                title: String(localized: .powerModeSettingsAdjustmentConfirmed),
                systemImage: "checkmark.circle.fill",
                emphasis: .positive
            )
        case .failed(let resultID, let message) where resultID == id:
            return .init(
                state: .failed,
                title: message,
                systemImage: "exclamationmark.triangle.fill",
                emphasis: .critical
            )
        default:
            return .idle
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return String(localized: .powerModeSettingsUnavailable) }
        return value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(0 ... 1))
        )
    }

    private func supportedRegeneration(_ value: Double?) -> Double? {
        guard let value, 0 ... 100 ~= value else { return nil }
        return value
    }

    private func maximumHorsepower(
        detectedTier: BikeDetectedPowerTier,
        declaredTier: BikeDeclaredPowerTier?
    ) -> Double {
        if case .alpha = detectedTier { return 80 }
        return declaredTier == .alpha ? 80 : 60
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

struct PowerModeControlData {
    let configuration: BikePowerModeConfiguration?
    let adjustments: [PowerModeAdjustmentViewState]
    let isTractionControlReady: Bool
}

private struct PowerModeAdjustmentMappingContext {
    let configuration: BikePowerModeConfiguration?
    let powerMaximum: Double
    let isBaseControlReady: Bool
    let isTractionControlReady: Bool
    let activeAdjustmentID: PowerModeAdjustmentID?
    let pendingValue: Double?
    let recentAdjustmentResult: PowerModeAdjustmentResult?
}

private struct PowerModeAdjustmentPresentationInput {
    let id: PowerModeAdjustmentID
    let title: String
    let value: Double?
    let unit: String
    let minimum: Double
    let maximum: Double
    let isEnabled: Bool
    let feedback: PowerModeControlFeedback
}
