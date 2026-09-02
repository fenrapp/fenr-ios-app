import SettingsDomain

public struct BikeLockCardViewStateMapper: Sendable {
    public init() {}

    func map(_ input: BikeLockCardMappingInput) -> BikeLockCardViewState {
        let isAvailable = input.firmware != nil
        let status = rideDashboardLocalized(
            input.isLocked ? .rideDashboardBikeLockStatusLocked : .rideDashboardBikeLockStatusUnlocked
        )
        let actionTitle = input.isLocked
            ? rideDashboardLocalized(.rideDashboardBikeLockActionUnlock)
            : rideDashboardLocalized(
                input.securityMode.isConfigured
                    ? .rideDashboardBikeLockActionLock
                    : .rideDashboardBikeLockActionSetUp
            )
        return .init(
            isAvailable: isAvailable,
            isLocked: input.isLocked,
            isWorking: input.isWorking,
            isActionEnabled: isAvailable
                && input.isReceivingTelemetry
                && input.isVehicleStationary
                && !input.isWorking,
            isConfigured: input.securityMode.isConfigured,
            statusText: isAvailable ? status : rideDashboardLocalized(.rideDashboardCommonUnavailable),
            actionTitle: actionTitle,
            detailText: isAvailable
                ? rideDashboardLocalized(.rideDashboardBikeLockDetailFirmware(input.firmware ?? ""))
                : rideDashboardLocalized(.rideDashboardBikeLockDetailMinimumFirmware),
            errorText: input.error,
            sheet: input.sheetUpdate.resolve(current: input.currentSheet)
        )
    }
}

struct BikeLockCardMappingInput {
    let firmware: String?
    let isLocked: Bool
    let isWorking: Bool
    let isReceivingTelemetry: Bool
    let isVehicleStationary: Bool
    let securityMode: BikeLockSecurityMode
    let error: String?
    let sheetUpdate: BikeLockSheetUpdate
    let currentSheet: BikeLockCardViewState.Sheet?
}
