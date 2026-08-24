public struct BikeChargePowerControlSnapshot: Equatable, Sendable {
    public let vcuFirmware: String?
    public let isFirmwareCompatible: Bool
    public let readRequestHex: String
    public let readResponseHex: String
    public let parsedConfig: BikeChargePowerConfiguration
    public let lastWriteHex: String?
    public let didPassNoOpWrite: Bool
    public let logLines: [String]

    public init(
        vcuFirmware: String?,
        isFirmwareCompatible: Bool,
        readRequestHex: String,
        readResponseHex: String,
        parsedConfig: BikeChargePowerConfiguration,
        lastWriteHex: String?,
        didPassNoOpWrite: Bool,
        logLines: [String]
    ) {
        self.vcuFirmware = vcuFirmware
        self.isFirmwareCompatible = isFirmwareCompatible
        self.readRequestHex = readRequestHex
        self.readResponseHex = readResponseHex
        self.parsedConfig = parsedConfig
        self.lastWriteHex = lastWriteHex
        self.didPassNoOpWrite = didPassNoOpWrite
        self.logLines = logLines
    }
}

public struct BikeChargePowerConfiguration: Equatable, Sendable {
    public let chargeCurrentDeciAmperes: Int
    public let chargePowerWatts: Int
    public let maximumStateOfChargeDeciPercent: Int
    public let standardChargerMaximumPowerWatts: Int
    public let backpackChargerMaximumPowerWatts: Int

    public init(
        chargeCurrentDeciAmperes: Int,
        chargePowerWatts: Int,
        maximumStateOfChargeDeciPercent: Int,
        standardChargerMaximumPowerWatts: Int,
        backpackChargerMaximumPowerWatts: Int
    ) {
        self.chargeCurrentDeciAmperes = chargeCurrentDeciAmperes
        self.chargePowerWatts = chargePowerWatts
        self.maximumStateOfChargeDeciPercent = maximumStateOfChargeDeciPercent
        self.standardChargerMaximumPowerWatts = standardChargerMaximumPowerWatts
        self.backpackChargerMaximumPowerWatts = backpackChargerMaximumPowerWatts
    }
}
