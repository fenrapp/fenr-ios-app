import BikeDomain

enum DashboardGearMapper {
    static func map(telemetry: BikeTelemetry, hasTelemetry: Bool, modeName: String?) -> DashboardGearViewData {
        map(
            runState: hasTelemetry ? telemetry.runState : .unknown,
            modeIndex: hasTelemetry ? telemetry.mode.displayIndex : nil,
            modeName: hasTelemetry ? modeName : nil,
            hasAdvancedCurve: telemetry.activePowerModeConfiguration?.curveConfirmation.hasAdvancedCurve == true
        )
    }

    static func map(
        runState: BikeRunState,
        modeIndex: Int?,
        modeName: String?,
        hasAdvancedCurve: Bool = false
    ) -> DashboardGearViewData {
        switch runState {
        case .unknown:
            .init(
                display: .text("--"),
                isActive: false,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardGearUnavailableAccessibility)
            )
        case .off:
            .init(
                display: .text(rideDashboardLocalized(.rideDashboardGearDisplayOff)),
                isActive: false,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardGearOffAccessibility)
            )
        case .neutral, .charging:
            .init(
                display: .text(rideDashboardLocalized(.rideDashboardGearDisplayNeutral)),
                isActive: true,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardGearNeutralAccessibility)
            )
        case .on:
            powerMode(modeIndex: modeIndex, modeName: modeName, hasAdvancedCurve: hasAdvancedCurve)
        case .crawlForward:
            .init(
                display: .crawlForward,
                isActive: true,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardGearCrawlForwardAccessibility)
            )
        case .crawlReverse:
            .init(
                display: .crawlReverse,
                isActive: true,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardGearCrawlReverseAccessibility)
            )
        }
    }

    private static func powerMode(
        modeIndex: Int?, modeName: String?, hasAdvancedCurve: Bool
    ) -> DashboardGearViewData {
        let display = modeName ?? modeIndex.map(String.init) ?? "--"
        return .init(
            display: .text(display),
            isActive: true,
            showsAdvancedCurve: modeIndex.map { 1 ... 5 ~= $0 } == true && hasAdvancedCurve,
            accessibilityLabel: display == "--"
                ? rideDashboardLocalized(.rideDashboardPowerModeUnavailableAccessibility)
                : rideDashboardLocalized(.rideDashboardAccessibilityPowerMode(display))
        )
    }
}
