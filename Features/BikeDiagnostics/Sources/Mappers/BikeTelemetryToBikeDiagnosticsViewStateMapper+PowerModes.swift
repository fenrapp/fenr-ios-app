import BikeDomain
import Foundation
import VehicleSession

extension BikeTelemetryToBikeDiagnosticsViewStateMapper {
    func powerModeConfigurations(
        _ telemetry: BikeTelemetry
    ) -> [BikeDiagnosticsPowerModeViewData] {
        telemetry.powerModeConfigurations.keys.sorted().compactMap { index in
            guard let configuration = telemetry.powerModeConfigurations[index] else { return nil }
            let horsepower = configuration.horsepower.map { "\($0) hp" } ?? BikeDiagnosticsText.placeholder
            return .init(
                id: index,
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricMap(index + 1)),
                isActive: index == telemetry.mode.powerModeConfigurationIndex,
                metrics: [
                    .init(
                        id: "power",
                        title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricPower),
                        value: horsepower
                    ),
                    .init(
                        id: "regeneration",
                        title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricRegen),
                        value: percent(configuration.regenerativeBrakingPercent)
                    ),
                    .init(
                        id: "powerTraction",
                        title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricPowerTc),
                        value: percent(configuration.powerTractionPercent)
                    ),
                    .init(
                        id: "brakingTraction",
                        title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricRegenTc),
                        value: percent(configuration.brakingTractionPercent)
                    )
                ]
            )
        }
    }

    func configurationMetrics(_ telemetry: BikeTelemetry) -> [BikeDiagnosticsMetricViewData] {
        guard !telemetry.powerModeConfigurations.isEmpty else {
            return [.init(
                id: "configurationUnavailable",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricConfigurations),
                value: BikeDiagnosticsText.placeholder
            )]
        }
        return telemetry.powerModeConfigurations.keys.sorted().map { index in
            guard let configuration = telemetry.powerModeConfigurations[index] else {
                return .init(
                    id: "configuration\(index)",
                    title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricMap(index + 1)),
                    value: BikeDiagnosticsText.placeholder
                )
            }
            let horsepower = configuration.horsepower.map { "\($0) hp" } ?? BikeDiagnosticsText.placeholder
            let regeneration = percent(configuration.regenerativeBrakingPercent, suffix: "regen")
            let powerTraction = percent(configuration.powerTractionPercent, suffix: "power TC")
            let brakingTraction = percent(configuration.brakingTractionPercent, suffix: "regen TC")
            return .init(
                id: "configuration\(index)",
                title: index == telemetry.mode.powerModeConfigurationIndex
                    ? BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricMapActive(index + 1))
                    : BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricMap(index + 1)),
                value: [horsepower, regeneration, powerTraction, brakingTraction]
                    .joined(separator: ", ")
            )
        }
    }

    func powerTierMetrics(_ snapshot: VehicleSessionSnapshot) -> [BikeDiagnosticsMetricViewData] {
        let declared = snapshot.profile.map { declaredTierText($0.declaredPowerTier) }
            ?? BikeDiagnosticsText.placeholder
        let evidence = snapshot.telemetry.detectedPowerTier.alphaEvidence
            .map(evidenceText)
            .sorted()
        return [
            .init(
                id: "declaredPowerTier",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricDeclaredTier),
                value: declared
            ),
            .init(
                id: "detectedPowerTier",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricDetectedTier),
                value: detectedTierText(snapshot.telemetry.detectedPowerTier)
            ),
            .init(
                id: "powerTierEvidence",
                title: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricEvidence),
                value: evidence.isEmpty
                    ? BikeDiagnosticsL10n.text(.bikeDiagnosticsValueNone)
                    : evidence.joined(separator: ", ")
            )
        ]
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return BikeDiagnosticsText.placeholder }
        return "\(value.formatted(.number.precision(.fractionLength(0 ... 1))))%"
    }

    private func percent(_ value: Double?, suffix: String) -> String {
        guard let value else { return BikeDiagnosticsText.placeholder }
        return "\(value.formatted(.number.precision(.fractionLength(0 ... 1))))% \(suffix)"
    }

    private func declaredTierText(_ tier: BikeDeclaredPowerTier) -> String {
        switch tier {
        case .standard: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueStandard)
        case .alpha: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueAlpha)
        }
    }

    private func detectedTierText(_ tier: BikeDetectedPowerTier) -> String {
        switch tier {
        case .standardBaseline: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueStandardBaseline)
        case .alpha: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueAlpha)
        }
    }

    private func evidenceText(_ evidence: BikeAlphaEvidence) -> String {
        switch evidence {
        case .powerAboveStandard: BikeDiagnosticsL10n.text(.bikeDiagnosticsValuePowerAboveStandard)
        case .tractionControlConfigured: BikeDiagnosticsL10n.text(.bikeDiagnosticsValueTractionControlConfigured)
        }
    }
}
