public enum PowerModeControlGroupID: String, Equatable, Hashable, Sendable {
    case performance
    case traction
}

public struct PowerModeControlGroupViewData: Equatable, Identifiable, Sendable {
    public let id: PowerModeControlGroupID
    public let title: String
    public let detail: String?
    public let adjustments: [PowerModeAdjustmentViewState]

    public init(
        id: PowerModeControlGroupID,
        title: String,
        detail: String?,
        adjustments: [PowerModeAdjustmentViewState]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.adjustments = adjustments
    }
}
