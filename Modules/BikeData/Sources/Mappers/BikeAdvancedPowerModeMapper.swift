import BikeDomain
import BikeSDK

public struct BikeAdvancedPowerModeMapper: Sendable {
    public init() {}

    public func map(_ value: BikeSDKAdvancedPowerModeConfiguration) -> BikeAdvancedPowerModeConfiguration {
        .init(
            mapIndex: value.mapIndex, firmware: value.firmware, torqueRaw: value.torqueRaw,
            regenerationRaw: value.regenerationRaw, curve: value.curve, power: value.power,
            regeneration: value.regeneration, powerTractionRaw: value.powerTractionRaw,
            brakingTractionRaw: value.brakingTractionRaw
        )
    }

    public func map(_ value: BikeAdvancedPowerModeConfiguration) -> BikeSDKAdvancedPowerModeConfiguration {
        .init(
            mapIndex: value.mapIndex, firmware: value.firmware, torqueRaw: value.torqueRaw,
            regenerationRaw: value.regenerationRaw, curve: value.curve, power: value.power,
            regeneration: value.regeneration, powerTractionRaw: value.powerTractionRaw,
            brakingTractionRaw: value.brakingTractionRaw
        )
    }
}
