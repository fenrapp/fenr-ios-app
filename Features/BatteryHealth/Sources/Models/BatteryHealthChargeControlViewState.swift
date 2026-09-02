import Foundation

public struct BatteryHealthChargeControlViewState: Equatable, Sendable {
    public let isVisible: Bool
    public let isEnabled: Bool
    public let power: BatteryHealthAdjustmentViewState
    public let target: BatteryHealthAdjustmentViewState
    public let chargerText: String
    public let statusText: String
    public let statusIsError: Bool
    public let errorText: String?

    public init(
        isVisible: Bool = false,
        isEnabled: Bool = false,
        power: BatteryHealthAdjustmentViewState = .init(
            selected: 300,
            minimum: 300,
            maximum: 3_300,
            step: 100
        ),
        target: BatteryHealthAdjustmentViewState = .init(
            selected: 100,
            minimum: 1,
            maximum: 100,
            step: 1
        ),
        chargerText: String? = nil,
        statusText: String? = nil,
        statusIsError: Bool = false,
        errorText: String? = nil
    ) {
        self.isVisible = isVisible
        self.isEnabled = isEnabled
        self.power = power
        self.target = target
        self.chargerText = chargerText ?? String(localized: .batteryHealthChargerUnknown)
        self.statusText = statusText ?? String(localized: .batteryHealthChargeControlStatusUnavailable)
        self.statusIsError = statusIsError
        self.errorText = errorText
    }
}
