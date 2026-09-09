import BikeDomain

struct PowerModeAdvancedMappingInput {
    let draft: PowerModeCurveDraft?
    let kind: PowerModeCurveKind
    let maximum: Int
    let canEdit: Bool
    let isBusy: Bool
    let message: String?
    let presets: [BikePowerModePreset]
    let presetsLoaded: Bool
    let isBaselineCurrent: Bool
}
