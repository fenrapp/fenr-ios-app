import BikeDomain
import Foundation

struct PowerModeAdvancedViewStateMapper: Sendable {
    private let calibration: BikePowerCurveCalibration
    private let locale: Locale
    private let presetCompatibility: PowerModePresetCompatibility

    init(calibration: BikePowerCurveCalibration, locale: Locale, presetCompatibility: PowerModePresetCompatibility) {
        self.calibration = calibration
        self.locale = locale
        self.presetCompatibility = presetCompatibility
    }

    func map(_ input: PowerModeAdvancedMappingInput) -> PowerModeAdvancedViewState {
        let draft = input.draft
        let kind = input.kind
        let maximum = input.maximum
        let canEdit = input.canEdit
        let isBusy = input.isBusy
        let values = kind == .power ? draft?.powerPoints : draft?.regenerationPoints
        let indexes = BikePowerCurveCalibration.editorSampleIndexes
        let points = (values ?? []).enumerated().map { index, value in
            PowerCurvePointViewData(
                id: index, rpm: Double(BikePowerCurveCalibration.editorRPM[index]),
                rpmText: BikePowerCurveCalibration.editorRPM[index].formatted(.number.locale(locale)),
                value: value,
                maximum: kind == .power ? calibration.maximum(at: indexes[index], maximumHorsepower: maximum) : 100
            )
        }
        let configuration = draft?.configuration
        let valid = configuration.map {
            $0.power.count == 15 && $0.regeneration.count == 15
                && $0.power.allSatisfy { 0 ... 1_000 ~= $0 }
                && $0.regeneration.allSatisfy { 0 ... 1_000 ~= $0 }
        } ?? false
        let rideable = configuration.map {
            calibration.isRideable($0.power, maximumHorsepower: maximum)
        } ?? false
        let horsepower = configuration.map { calibration.summaryHorsepower($0.power, maximumHorsepower: maximum) } ?? 0
        return .init(
            tractionAdjustments: tractionRows(configuration, enabled: canEdit && valid && !isBusy),
            points: points, samples: samples(configuration, kind: kind, maximum: maximum), kind: kind,
            unit: kind == .power
                ? String(localized: .powerModeSettingsHorsepowerUnit)
                : String(localized: .powerModeSettingsPercentUnit),
            summary: kind == .power ? String(localized: .powerCurveSummary(horsepower))
                : String(localized: .powerCurveRegenSummary(
                    (Double(configuration?.regeneration.max() ?? 0) / 10)
                        .formatted(.number.locale(locale).precision(.fractionLength(0)))
                )),
            canEdit: canEdit && valid && !isBusy,
            canApply: canEdit && valid && rideable && !isBusy && input.isBaselineCurrent && draft?.hasChanges == true
                && configuration.map { 13 ... 100 ~= $0.torqueRaw && $0.power.contains { $0 > 0 } } == true,
            hasDraft: draft?.hasChanges == true, isBusy: isBusy,
            hasConfiguration: draft != nil,
            message: input.message ?? (draft?.hasChanges == true && !input.isBaselineCurrent
                ? String(localized: .powerCurveStaleDraft)
                : (draft != nil && !rideable ? String(localized: .powerCurveMinimumPower) : nil)),
            presets: input.presets.map { .init(
                id: $0.id, name: $0.name,
                isCompatible: presetCompatibility.accepts($0, configuration: configuration, maximum: maximum)
            )
            },
            canSavePreset: canEdit && valid && !isBusy && input.presetsLoaded
        )
    }

    private func samples(
        _ configuration: BikeAdvancedPowerModeConfiguration?, kind: PowerModeCurveKind, maximum: Int
    ) -> [PowerCurvePointViewData] {
        let raw = kind == .power ? configuration?.power : configuration?.regeneration
        return (raw ?? []).enumerated().map { index, value in
            let rpm = (index + 1) * 1_000
            return .init(
                id: index, rpm: Double(rpm), rpmText: rpm.formatted(.number.locale(locale)),
                value: kind == .power
                    ? calibration.horsepower(raw: value, index: index, maximumHorsepower: maximum)
                    : Double(value) / 10,
                maximum: kind == .power ? calibration.maximum(at: index, maximumHorsepower: maximum) : 100
            )
        }
    }

    private func tractionRows(
        _ configuration: BikeAdvancedPowerModeConfiguration?, enabled: Bool
    ) -> [PowerModeAdjustmentViewState] {
        let identifiers: [PowerModeAdjustmentID] = [.powerTraction, .brakingTraction]
        return identifiers.map { id in
            let title = id == .powerTraction
                ? String(localized: .powerModeSettingsTractionAdjustment)
                : String(localized: .powerModeSettingsRegenTractionAdjustment)
            let value = traction(
                id == .powerTraction ? configuration?.powerTractionRaw : configuration?.brakingTractionRaw
            )
            return .init(
                id: id, title: title, value: value,
                valueText: value.map { $0.formatted(.number.locale(locale).precision(.fractionLength(0))) }
                    ?? String(localized: .powerModeSettingsUnavailable),
                unit: String(localized: .powerModeSettingsPercentUnit), minimum: 0, maximum: 100, step: 1,
                isEnabled: enabled && traction(configuration?.powerTractionRaw) != nil
                    && traction(configuration?.brakingTractionRaw) != nil,
                localeIdentifier: locale.identifier,
                feedback: .idle
            )
        }
    }

    private func traction(_ value: Int?) -> Double? {
        guard let value, 0 ... 1_000 ~= value, value.isMultiple(of: 10) else { return nil }
        return Double(value) / 10
    }
}
