public struct PowerModeSettingsViewState: Equatable, Sendable {
    public let maps: [PowerModeMapViewData]
    public let selectedMapIndex: Int
    public let currentName: String
    public let maximumNameLength: Int
    public let canEditName: Bool
    public let nameError: String?
    public let connectionText: String
    public let capabilityText: String
    public let statusText: String
    public let statusIsError: Bool
    public let canRefresh: Bool
    public let adjustments: [PowerModeAdjustmentViewState]

    public init(
        maps: [PowerModeMapViewData] = [],
        selectedMapIndex: Int = 0,
        currentName: String = "",
        maximumNameLength: Int = 10,
        canEditName: Bool = false,
        nameError: String? = nil,
        connectionText: String = "Bike unavailable",
        capabilityText: String = "Capability unavailable",
        statusText: String = "Waiting for bike data",
        statusIsError: Bool = false,
        canRefresh: Bool = false,
        adjustments: [PowerModeAdjustmentViewState] = []
    ) {
        self.maps = maps
        self.selectedMapIndex = selectedMapIndex
        self.currentName = currentName
        self.maximumNameLength = maximumNameLength
        self.canEditName = canEditName
        self.nameError = nameError
        self.connectionText = connectionText
        self.capabilityText = capabilityText
        self.statusText = statusText
        self.statusIsError = statusIsError
        self.canRefresh = canRefresh
        self.adjustments = adjustments
    }
}
