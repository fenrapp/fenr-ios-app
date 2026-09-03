import Foundation

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
    public let status: PowerModeStatusViewData
    public let canRefresh: Bool
    public let controlGroups: [PowerModeControlGroupViewData]

    public var adjustments: [PowerModeAdjustmentViewState] {
        controlGroups.flatMap(\.adjustments)
    }

    public init(
        maps: [PowerModeMapViewData] = [],
        selectedMapIndex: Int = 0,
        currentName: String = "",
        maximumNameLength: Int = 10,
        canEditName: Bool = false,
        nameError: String? = nil,
        connectionText: String? = nil,
        capabilityText: String? = nil,
        statusText: String? = nil,
        statusIsError: Bool = false,
        status: PowerModeStatusViewData? = nil,
        canRefresh: Bool = false,
        controlGroups: [PowerModeControlGroupViewData] = [],
        adjustments: [PowerModeAdjustmentViewState] = []
    ) {
        self.maps = maps
        self.selectedMapIndex = selectedMapIndex
        self.currentName = currentName
        self.maximumNameLength = maximumNameLength
        self.canEditName = canEditName
        self.nameError = nameError
        self.connectionText = connectionText
            ?? String(localized: .powerModeSettingsBikeUnavailable)
        self.capabilityText = capabilityText
            ?? String(localized: .powerModeSettingsCapabilityUnavailable)
        self.statusText = statusText
            ?? String(localized: .powerModeSettingsWaitingForBikeData)
        self.statusIsError = statusIsError
        self.status = status ?? .init(
            title: self.connectionText,
            detail: [self.statusText, self.capabilityText]
                .formatted(.list(type: .and, width: .narrow)),
            systemImage: statusIsError
                ? "exclamationmark.triangle.fill"
                : "motorcycle",
            emphasis: statusIsError ? .critical : .neutral,
            isActivity: false
        )
        self.canRefresh = canRefresh
        if controlGroups.isEmpty, !adjustments.isEmpty {
            self.controlGroups = [
                .init(
                    id: .performance,
                    title: String(localized: .powerModeSettingsPerformanceGroupTitle),
                    detail: String(localized: .powerModeSettingsPerformanceGroupDetail),
                    adjustments: adjustments.filter {
                        $0.id == .power || $0.id == .regeneration
                    }
                ),
                .init(
                    id: .traction,
                    title: String(localized: .powerModeSettingsTractionGroupTitle),
                    detail: String(localized: .powerModeSettingsTractionGroupDetail),
                    adjustments: adjustments.filter {
                        $0.id == .powerTraction || $0.id == .brakingTraction
                    }
                )
            ]
        } else {
            self.controlGroups = controlGroups
        }
    }
}
