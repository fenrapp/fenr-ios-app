import BikeDomain
import BikeSDK

public struct BikeSDKChargePowerControlToDomainMapper: Sendable {
    public init() {}

    public func map(_ snapshot: BikeSDKChargePowerControlSnapshot) -> BikeChargePowerControlSnapshot {
        BikeChargePowerControlSnapshot(
            vcuFirmware: snapshot.vcuFirmware,
            isFirmwareCompatible: snapshot.isFirmwareCompatible,
            readRequestHex: snapshot.readRequestHex,
            readResponseHex: snapshot.readResponseHex,
            parsedConfig: .init(
                chargeCurrentDeciAmperes: snapshot.parsedConfig.chargeCurrentDeciAmperes,
                chargePowerWatts: snapshot.parsedConfig.chargePowerWatts,
                maximumStateOfChargeDeciPercent: snapshot.parsedConfig.maximumStateOfChargeDeciPercent,
                standardChargerMaximumPowerWatts: snapshot.parsedConfig.standardChargerMaximumPowerWatts,
                backpackChargerMaximumPowerWatts: snapshot.parsedConfig.backpackChargerMaximumPowerWatts
            ),
            lastWriteHex: snapshot.lastWriteHex,
            didPassNoOpWrite: snapshot.didPassNoOpWrite,
            logLines: snapshot.logLines
        )
    }
}
