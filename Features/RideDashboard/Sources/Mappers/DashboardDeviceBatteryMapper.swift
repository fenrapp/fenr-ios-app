import SettingsDomain

public struct DashboardDeviceBatteryMapper: Sendable {
    public init() {}

    public func map(
        snapshot: DashboardDeviceBatterySnapshot,
        displayMode: DashboardDeviceBatteryDisplayMode
    ) -> DashboardDeviceBatteryViewData {
        let presentation = presentation(for: displayMode)
        guard let level = snapshot.level, level.isFinite, level >= .zero else {
            return .init(
                isVisible: presentation.isVisible,
                showsIcon: presentation.showsIcon,
                showsPercentage: presentation.showsPercentage,
                displayModeAccessibilityHint: presentation.accessibilityHint
            )
        }
        let percent = min(max(Int((level * Constants.percentageScale).rounded()), .zero), 100)
        let emphasis: DashboardDeviceBatteryViewData.Emphasis
        if snapshot.isCharging {
            emphasis = .charging
        } else if percent <= Constants.lowBatteryPercent {
            emphasis = .low
        } else {
            emphasis = .normal
        }
        return .init(
            percentageText: "\(percent)%",
            systemImage: batterySymbol(percent: percent),
            emphasis: emphasis,
            accessibilityLabel: rideDashboardLocalized(
                snapshot.isCharging
                    ? .rideDashboardDeviceBatteryChargingAccessibility(percent)
                    : .rideDashboardDeviceBatteryAccessibility(percent)
            ),
            isVisible: presentation.isVisible,
            showsIcon: presentation.showsIcon,
            showsPercentage: presentation.showsPercentage,
            displayModeAccessibilityHint: presentation.accessibilityHint
        )
    }

    private func presentation(
        for displayMode: DashboardDeviceBatteryDisplayMode
    ) -> DisplayModePresentation {
        switch displayMode {
        case .iconAndText:
            .init(
                isVisible: true,
                showsIcon: true,
                showsPercentage: true,
                accessibilityHint: rideDashboardLocalized(.rideDashboardDeviceBatteryDisplayPercentageHint)
            )
        case .textOnly:
            .init(
                isVisible: true,
                showsIcon: false,
                showsPercentage: true,
                accessibilityHint: rideDashboardLocalized(.rideDashboardDeviceBatteryDisplayIconHint)
            )
        case .iconOnly:
            .init(
                isVisible: true,
                showsIcon: true,
                showsPercentage: false,
                accessibilityHint: rideDashboardLocalized(.rideDashboardDeviceBatteryDisplayBothHint)
            )
        case .hidden:
            .init(
                isVisible: false,
                showsIcon: false,
                showsPercentage: false,
                accessibilityHint: ""
            )
        }
    }

    private func batterySymbol(percent: Int) -> String {
        switch percent {
        case ...10: "battery.0percent"
        case ...37: "battery.25percent"
        case ...62: "battery.50percent"
        case ...87: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private struct DisplayModePresentation {
        let isVisible: Bool
        let showsIcon: Bool
        let showsPercentage: Bool
        let accessibilityHint: String
    }

    private enum Constants {
        static let percentageScale = 100.0
        static let lowBatteryPercent = 20
    }
}
