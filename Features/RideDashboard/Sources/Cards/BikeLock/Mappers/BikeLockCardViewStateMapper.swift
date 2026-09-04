import SettingsDomain

public struct BikeLockCardViewStateMapper: Sendable {
    public init() {}

    func map(_ input: BikeLockCardMappingInput) -> BikeLockCardViewState {
        let isAvailable = input.isFirmwareCompatible
        let status = if input.hasConfirmedLockState {
            rideDashboardLocalized(
                input.isLocked ? .rideDashboardBikeLockStatusLocked : .rideDashboardBikeLockStatusUnlocked
            )
        } else {
            rideDashboardLocalized(.rideDashboardBikeLockStatusAwaitingConfirmation)
        }
        let actionTitle = input.isLocked
            ? rideDashboardLocalized(.rideDashboardBikeLockActionUnlock)
            : rideDashboardLocalized(
                input.securityMode.isConfigured
                    ? .rideDashboardBikeLockActionLock
                    : .rideDashboardBikeLockActionSetUp
            )
        return .init(
            isAvailable: isAvailable,
            isLocked: input.hasConfirmedLockState && input.isLocked,
            isWorking: input.isWorking,
            isActionEnabled: isAvailable
                && input.isControlPrepared
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
    let isFirmwareCompatible: Bool
    let isControlPrepared: Bool
    let isLocked: Bool
    let hasConfirmedLockState: Bool
    let isWorking: Bool
    let isReceivingTelemetry: Bool
    let isVehicleStationary: Bool
    let securityMode: BikeLockSecurityMode
    let error: String?
    let sheetUpdate: BikeLockSheetUpdate
    let currentSheet: BikeLockCardViewState.Sheet?
}
