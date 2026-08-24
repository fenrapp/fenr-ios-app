import Foundation

public struct StarkChargerConfiguration: Equatable, Sendable {
    public let save: UInt8
    public let chargeCurrentDeciAmperes: Int
    public let chargePowerWatts: Int
    public let maximumStateOfChargeDeciPercent: Int
    public let standardChargerMaximumPowerWatts: Int
    public let backpackChargerMaximumPowerWatts: Int

    public init(
        save: UInt8 = 1,
        chargeCurrentDeciAmperes: Int,
        chargePowerWatts: Int,
        maximumStateOfChargeDeciPercent: Int,
        standardChargerMaximumPowerWatts: Int,
        backpackChargerMaximumPowerWatts: Int
    ) {
        self.save = save
        self.chargeCurrentDeciAmperes = chargeCurrentDeciAmperes
        self.chargePowerWatts = chargePowerWatts
        self.maximumStateOfChargeDeciPercent = maximumStateOfChargeDeciPercent
        self.standardChargerMaximumPowerWatts = standardChargerMaximumPowerWatts
        self.backpackChargerMaximumPowerWatts = backpackChargerMaximumPowerWatts
    }

    public func settingChargePower(_ watts: Int) -> Self {
        return Self(
            save: save,
            chargeCurrentDeciAmperes: chargeCurrentDeciAmperes,
            chargePowerWatts: watts,
            maximumStateOfChargeDeciPercent: maximumStateOfChargeDeciPercent,
            standardChargerMaximumPowerWatts: standardChargerMaximumPowerWatts,
            backpackChargerMaximumPowerWatts: backpackChargerMaximumPowerWatts
        )
    }

    public func settingMaximumStateOfCharge(percent: Int) -> Self {
        return Self(
            save: save,
            chargeCurrentDeciAmperes: chargeCurrentDeciAmperes,
            chargePowerWatts: chargePowerWatts,
            maximumStateOfChargeDeciPercent: percent * 10,
            standardChargerMaximumPowerWatts: standardChargerMaximumPowerWatts,
            backpackChargerMaximumPowerWatts: backpackChargerMaximumPowerWatts
        )
    }
}

public enum StarkChargerConfigurationCommand {
    public static let readPacket = Data([0x00, 0x04])
    public static let writePacketLength = 13

    public static func encodeWrite(_ configuration: StarkChargerConfiguration) throws -> Data {
        var data = Data([0x01, 0x04, configuration.save])
        try appendUInt16LE(configuration.chargeCurrentDeciAmperes, to: &data)
        try appendUInt16LE(configuration.chargePowerWatts, to: &data)
        try appendUInt16LE(configuration.maximumStateOfChargeDeciPercent, to: &data)
        try appendUInt16LE(configuration.standardChargerMaximumPowerWatts, to: &data)
        try appendUInt16LE(configuration.backpackChargerMaximumPowerWatts, to: &data)
        return data
    }

    public static func decodeResponse(_ data: Data) throws -> StarkChargerConfiguration {
        let payload: Data
        if data.count >= writePacketLength, data.first == 0x01 || data.first == 0x00 {
            payload = data.dropFirst(2)
        } else {
            payload = data
        }

        guard payload.count >= 11 else {
            throw StarkProtocolError.payloadTooShort(expected: 11, actual: payload.count)
        }
        let reader = StarkByteReader(data: payload)
        return StarkChargerConfiguration(
            save: reader.u8(at: 0),
            chargeCurrentDeciAmperes: Int(reader.u16(at: 1)),
            chargePowerWatts: Int(reader.u16(at: 3)),
            maximumStateOfChargeDeciPercent: Int(reader.u16(at: 5)),
            standardChargerMaximumPowerWatts: Int(reader.u16(at: 7)),
            backpackChargerMaximumPowerWatts: Int(reader.u16(at: 9))
        )
    }

    private static func appendUInt16LE(_ value: Int, to data: inout Data) throws {
        guard (0 ... Int(UInt16.max)).contains(value) else {
            throw StarkProtocolError.invalidPayloadLength(expected: Int(UInt16.max), actual: value)
        }
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }
}
