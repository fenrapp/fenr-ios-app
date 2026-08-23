import Foundation

public struct StarkChargerDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkChargerPayload {
        guard data.count == StarkChargerPayloadLayout.length else {
            throw StarkProtocolError.invalidPayloadLength(
                expected: StarkChargerPayloadLayout.length,
                actual: data.count
            )
        }

        let reader = StarkByteReader(data: data)
        return StarkChargerPayload(
            requestedCurrentAmperes: amperes(reader.u16(at: StarkChargerPayloadLayout.requestedCurrentOffset)),
            reportedCurrentAmperes: amperes(reader.u16(at: StarkChargerPayloadLayout.reportedCurrentOffset)),
            targetCellVoltageVolts: cellVoltage(reader.u16(at: StarkChargerPayloadLayout.targetCellVoltageOffset)),
            maximumCurrentAmperes: amperes(reader.u16(at: StarkChargerPayloadLayout.maximumCurrentOffset)),
            maximumPowerWatts: Double(reader.u16(at: StarkChargerPayloadLayout.maximumPowerOffset)),
            maximumStateOfChargePercent: Int(reader.u16(at: StarkChargerPayloadLayout.maximumStateOfChargeOffset)),
            requestedVoltageRaw: Int(reader.u16(at: StarkChargerPayloadLayout.requestedVoltageOffset)),
            reportedVoltageRaw: Int(reader.u16(at: StarkChargerPayloadLayout.reportedVoltageOffset)),
            statusRaw: Int(reader.u8(at: StarkChargerPayloadLayout.statusOffset)),
            isEnabled: reader.u8(at: StarkChargerPayloadLayout.enabledOffset) != 0,
            typeRaw: Int(reader.u8(at: StarkChargerPayloadLayout.typeOffset))
        )
    }

    private func amperes(_ rawValue: UInt16) -> Double {
        Double(rawValue) / StarkChargerPayloadLayout.currentScale
    }

    private func cellVoltage(_ rawValue: UInt16) -> Double {
        Double(rawValue) / StarkChargerPayloadLayout.cellVoltageScale
    }
}
