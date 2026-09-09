public struct PowerModeAdvancedViewState: Equatable, Sendable {
    public let tractionAdjustments: [PowerModeAdjustmentViewState]
    public let samples: [PowerCurvePointViewData]
    public let points: [PowerCurvePointViewData]
    public let kind: PowerModeCurveKind
    public let unit: String
    public let summary: String
    public let canEdit: Bool
    public let canApply: Bool
    public let hasDraft: Bool
    public let isBusy: Bool
    public let hasConfiguration: Bool
    public let message: String?
    public let presets: [PowerModePresetViewData]
    public let canSavePreset: Bool

    public init(
        tractionAdjustments: [PowerModeAdjustmentViewState] = [],
        points: [PowerCurvePointViewData] = [], samples: [PowerCurvePointViewData] = [],
        kind: PowerModeCurveKind = .power,
        unit: String = "", summary: String = "", canEdit: Bool = false,
        canApply: Bool = false, hasDraft: Bool = false, isBusy: Bool = false,
        hasConfiguration: Bool = false, message: String? = nil,
        presets: [PowerModePresetViewData] = [], canSavePreset: Bool = false
    ) {
        self.tractionAdjustments = tractionAdjustments
        self.points = points
        self.samples = samples
        self.kind = kind
        self.unit = unit
        self.summary = summary
        self.canEdit = canEdit
        self.canApply = canApply
        self.hasDraft = hasDraft
        self.isBusy = isBusy
        self.hasConfiguration = hasConfiguration
        self.message = message
        self.presets = presets
        self.canSavePreset = canSavePreset
    }
}
