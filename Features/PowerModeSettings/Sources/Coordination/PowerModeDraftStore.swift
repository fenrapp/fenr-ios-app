import BikeDomain
import Observation

@MainActor
@Observable
final class PowerModeDraftStore {
    private let factory: PowerModeDraftFactory
    private let calibration: BikePowerCurveCalibration
    private let presetCompatibility: PowerModePresetCompatibility
    private(set) var configurations: [Int: BikeAdvancedPowerModeConfiguration] = [:]
    private(set) var drafts: [Int: PowerModeCurveDraft] = [:]

    init(
        factory: PowerModeDraftFactory, calibration: BikePowerCurveCalibration,
        presetCompatibility: PowerModePresetCompatibility
    ) {
        self.factory = factory
        self.calibration = calibration
        self.presetCompatibility = presetCompatibility
    }

    func clear() {
        configurations.removeAll()
        drafts.removeAll()
    }

    func invalidate(_ map: Int? = nil) {
        if let map { configurations[map] = nil } else { configurations.removeAll() }
    }

    func accept(_ value: BikeAdvancedPowerModeConfiguration, maximum: Int, replaceDraft: Bool = false) {
        guard value.power.count == 15, value.regeneration.count == 15 else { return }
        configurations[value.mapIndex] = value
        if replaceDraft || drafts[value.mapIndex]?.hasChanges != true {
            drafts[value.mapIndex] = factory.makeDraft(value, maximum: maximum)
        }
    }

    func discard(_ map: Int, maximum: Int) {
        guard let value = configurations[map] ?? drafts[map]?.baseline else { return }
        drafts[map] = factory.makeDraft(value, maximum: maximum)
    }

    func updatePoint(map: Int, kind: PowerModeCurveKind, index: Int, value: Double, maximum: Int) throws {
        guard value.isFinite, var draft = drafts[map], draft.powerPoints.indices.contains(index) else { return }
        switch kind {
        case .power:
            draft.powerPoints[index] = value
            draft.configuration = try calibration.updatingPower(
                draft.configuration, points: draft.powerPoints, maximumHorsepower: maximum
            )
        case .regeneration:
            draft.regenerationPoints[index] = value
            draft.configuration = try calibration.updatingRegeneration(
                draft.configuration, points: draft.regenerationPoints
            )
        }
        drafts[map] = draft
    }

    func updateTraction(map: Int, id: PowerModeAdjustmentID, value: Double) {
        guard value.isFinite, 0 ... 100 ~= value, value.rounded() == value,
              var draft = drafts[map], draft.configuration.powerTractionRaw != nil,
              draft.configuration.brakingTractionRaw != nil else { return }
        switch id {
        case .powerTraction: draft.configuration.powerTractionRaw = Int(value * 10)
        case .brakingTraction: draft.configuration.brakingTractionRaw = Int(value * 10)
        default: return
        }
        drafts[map] = draft
    }

    func acceptBasic(_ confirmed: BikeAdvancedPowerModeConfiguration, adjustment: PowerModeAdjustmentID, maximum: Int) {
        guard let draft = drafts[confirmed.mapIndex], draft.hasChanges else {
            accept(confirmed, maximum: maximum, replaceDraft: true)
            return
        }
        var desired = confirmed
        if adjustment != .power, draft.configuration.power != draft.baseline.power {
            desired.power = draft.configuration.power
            desired.torqueRaw = draft.configuration.torqueRaw
        }
        if adjustment != .regeneration, draft.configuration.regeneration != draft.baseline.regeneration {
            desired.regeneration = draft.configuration.regeneration
            desired.regenerationRaw = draft.configuration.regenerationRaw
        }
        if adjustment != .powerTraction, draft.configuration.powerTractionRaw != draft.baseline.powerTractionRaw {
            desired.powerTractionRaw = draft.configuration.powerTractionRaw
        }
        if adjustment != .brakingTraction, draft.configuration.brakingTractionRaw != draft.baseline.brakingTractionRaw {
            desired.brakingTractionRaw = draft.configuration.brakingTractionRaw
        }
        configurations[confirmed.mapIndex] = confirmed
        replaceDraft(desired, baseline: confirmed, maximum: maximum)
    }

    func load(_ preset: BikePowerModePreset, map: Int, maximum: Int) -> Bool {
        guard let current = configurations[map],
              presetCompatibility.accepts(preset, configuration: current, maximum: maximum) else {
            return false
        }
        var desired = current
        desired.power = preset.configuration.power
        desired.regeneration = preset.configuration.regeneration
        desired.torqueRaw = preset.configuration.torqueRaw
        desired.regenerationRaw = preset.configuration.regenerationRaw
        desired.powerTractionRaw = preset.configuration.powerTractionRaw
        desired.brakingTractionRaw = preset.configuration.brakingTractionRaw
        replaceDraft(desired, baseline: current, maximum: maximum)
        return true
    }

    private func replaceDraft(
        _ desired: BikeAdvancedPowerModeConfiguration, baseline: BikeAdvancedPowerModeConfiguration, maximum: Int
    ) {
        let values = factory.makeDraft(desired, maximum: maximum)
        drafts[baseline.mapIndex] = .init(
            baseline: baseline, configuration: desired,
            powerPoints: values.powerPoints, regenerationPoints: values.regenerationPoints
        )
    }
}
