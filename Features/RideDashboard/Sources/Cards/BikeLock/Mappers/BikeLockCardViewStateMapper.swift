import SettingsDomain

public struct BikeLockCardViewStateMapper: Sendable {
    public init() {}

    func map(_ input: BikeLockCardMappingInput) -> BikeLockCardViewState {
        let isAvailable = input.firmware != nil
        let status = input.isLocked ? "Locked" : "Unlocked"
        let actionTitle = input.isLocked
            ? "Unlock"
            : (input.securityMode.isConfigured ? "Lock" : "Set Up")
        return .init(
            isAvailable: isAvailable,
            isLocked: input.isLocked,
            isWorking: input.isWorking,
            isActionEnabled: isAvailable
                && input.isReceivingTelemetry
                && input.isVehicleStationary
                && !input.isWorking,
            isConfigured: input.securityMode.isConfigured,
            statusText: isAvailable ? status : "Unavailable",
            actionTitle: actionTitle,
            detailText: isAvailable
                ? "VCU PIC \(input.firmware ?? "")"
                : "Bike Lock requires VCU PIC 1.6.29 or newer.",
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
