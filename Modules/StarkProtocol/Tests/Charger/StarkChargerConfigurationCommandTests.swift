import Foundation
import StarkProtocol
import Testing

@Suite("Stark charger configuration command")
struct StarkChargerConfigurationCommandTests {
    @Test("Encodes modern 13 byte charger config payload")
    func encodesModernPayload() throws {
        let payload = try StarkChargerConfigurationCommand.encodeWrite(.init(
            chargeCurrentDeciAmperes: 80,
            chargePowerWatts: 3_300,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        ))

        #expect(payload.count == 13)
        #expect(payload[0] == 0x01)
        #expect(payload[1] == 0x04)
        #expect(payload[5] == 0xE4)
        #expect(payload[6] == 0x0C)
    }

    @Test("Encodes 7000 watts little endian")
    func encodesFastChargerPower() throws {
        let payload = try StarkChargerConfigurationCommand.encodeWrite(.init(
            chargeCurrentDeciAmperes: 170,
            chargePowerWatts: 7_000,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        ))

        #expect(payload[5] == 0x58)
        #expect(payload[6] == 0x1B)
    }

    @Test("Changing fast charge power repairs current and preserves both charger limits")
    func settingFastChargePowerRepairsCurrentAndPreservesLimits() throws {
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 20,
            chargePowerWatts: 3_300,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 7_000
        )

        let payload = try StarkChargerConfigurationCommand.encodeWrite(
            configuration.settingChargePower(7_000, chargerType: .fast)
        )

        #expect(payload[3] == 0xFA)
        #expect(payload[4] == 0x00)
        #expect(payload[5] == 0x58)
        #expect(payload[6] == 0x1B)
        #expect(payload[9] == 0xE4)
        #expect(payload[10] == 0x0C)
        #expect(payload[11] == 0x58)
        #expect(payload[12] == 0x1B)
    }

    @Test("Changing charge power preserves a configured current above the validated limit")
    func settingChargePowerPreservesHigherCurrent() throws {
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 250,
            chargePowerWatts: 2_000,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        )

        let payload = try StarkChargerConfigurationCommand.encodeWrite(
            configuration.settingChargePower(700, chargerType: .standard)
        )

        #expect(payload[3] == 0xFA)
        #expect(payload[4] == 0x00)
        #expect(payload[5] == 0xBC)
        #expect(payload[6] == 0x02)
    }

    @Test("Changing charge power preserves a non-regression current below twenty amperes")
    func settingChargePowerPreservesOtherLowerCurrent() throws {
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 100,
            chargePowerWatts: 2_000,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 7_000
        )

        let payload = try StarkChargerConfigurationCommand.encodeWrite(
            configuration.settingChargePower(700, chargerType: .standard)
        )

        #expect(payload[3] == 0x64)
        #expect(payload[4] == 0x00)
        #expect(payload[5] == 0xBC)
        #expect(payload[6] == 0x02)
    }

    @Test("Changing charge power repairs the two ampere regression")
    func settingChargePowerRepairsTwoAmpereRegression() throws {
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 20,
            chargePowerWatts: 500,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        )

        let payload = try StarkChargerConfigurationCommand.encodeWrite(
            configuration.settingChargePower(3_300, chargerType: .standard)
        )

        #expect(payload[3] == 0xC8)
        #expect(payload[4] == 0x00)
        #expect(payload[5] == 0xE4)
        #expect(payload[6] == 0x0C)
    }

    @Test("Encodes observed minimum 300 watts with the validated current limit")
    func encodesObservedMinimumChargePower() throws {
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 20,
            chargePowerWatts: 500,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        )

        let payload = try StarkChargerConfigurationCommand.encodeWrite(
            configuration.settingChargePower(
                StarkChargePowerControlLimits.minimumWatts,
                chargerType: .standard
            )
        )

        #expect(StarkChargePowerControlLimits.minimumWatts == 300)
        #expect(payload[3] == 0xC8)
        #expect(payload[4] == 0x00)
        #expect(payload[5] == 0x2C)
        #expect(payload[6] == 0x01)
    }

    @Test("Decodes the complete notified charger configuration response")
    func decodesNotifiedConfigurationResponse() throws {
        let response = Data([
            0x02, 0x04, 0x00,
            0xC8, 0x00,
            0xE4, 0x0C,
            0xE8, 0x03,
            0x14, 0x00,
            0x02, 0x00,
            0x10, 0x00,
            0xE4, 0x0C,
            0xE4, 0x0C
        ])

        let configuration = try StarkChargerConfigurationCommand.decodeResponse(response)

        #expect(configuration == StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 200,
            chargePowerWatts: 3_300,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        ))
    }

    @Test("Changing charge target preserves current and power")
    func settingChargeTargetPreservesCurrentAndPower() throws {
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 20,
            chargePowerWatts: 500,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        )

        let payload = try StarkChargerConfigurationCommand.encodeWrite(
            configuration.settingMaximumStateOfCharge(percent: 80)
        )

        #expect(payload.count == 13)
        #expect(payload[3] == 0x14)
        #expect(payload[4] == 0x00)
        #expect(payload[5] == 0xF4)
        #expect(payload[6] == 0x01)
        #expect(payload[7] == 0x20)
        #expect(payload[8] == 0x03)
    }

    @Test("Encodes one percent charge target as deci-percent")
    func encodesOnePercentChargeTarget() throws {
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: 20,
            chargePowerWatts: 500,
            maximumStateOfChargeDeciPercent: 1_000,
            standardChargerMaximumPowerWatts: 3_300,
            backpackChargerMaximumPowerWatts: 3_300
        )

        let payload = try StarkChargerConfigurationCommand.encodeWrite(
            configuration.settingMaximumStateOfCharge(percent: 1)
        )

        #expect(payload[7] == 0x0A)
        #expect(payload[8] == 0x00)
    }

    @Test("Firmware gate accepts only VCU PIC 1.9.1 and newer")
    func firmwareGate() {
        #expect(StarkFirmwareVersion("1.9.0")?.isChargePowerControlCompatible == false)
        #expect(StarkFirmwareVersion("1.9.1")?.isChargePowerControlCompatible == true)
        #expect(StarkFirmwareVersion("1.10.0")?.isChargePowerControlCompatible == true)
    }

    @Test("Firmware parser accepts binary major minor patch triplets")
    func firmwareParserAcceptsBinaryTriplets() {
        let version = StarkFirmwareVersionParser.parseVCUPic(from: Data([0x01, 0x09, 0x01]))

        #expect(version == StarkFirmwareVersion(major: 1, minor: 9, patch: 1))
        #expect(version?.isChargePowerControlCompatible == true)
    }

    @Test("Firmware parser reads VCU PIC from observed 4001 version blocks")
    func firmwareParserReadsVCUPicFromObservedVersionBlocks() {
        let payload = Data([
            0x00, 0x0C, 0x01, 0x00,
            0x00, 0x08, 0x01, 0x00,
            0x00, 0x09, 0x01, 0x00,
            0x00, 0x0C, 0x01, 0x00,
            0xDC, 0xBE, 0x2D, 0xEF
        ])

        let version = StarkFirmwareVersionParser.parseVCUPic(from: payload)
        let descriptions = StarkFirmwareVersionParser.parseVersionBlockDescriptions(from: payload)

        #expect(version == StarkFirmwareVersion(major: 1, minor: 12, patch: 0))
        #expect(version?.isChargePowerControlCompatible == true)
        #expect(descriptions == ["1.12.0", "1.8.0", "1.9.0", "1.12.0"])
    }
}
