import Foundation

public struct StarkBatteryDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkBatteryPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkBatteryPayloadLayout.minimumLength)

        let socRaw = Int(reader.u16(at: StarkBatteryPayloadLayout.stateOfChargeOffset))
        let sohRaw = data.count >= StarkBatteryPayloadLayout.lengthWithStateOfHealth
            ? Int(reader.u16(at: StarkBatteryPayloadLayout.stateOfHealthOffset))
            : nil
        let dcBusRaw = data.count >= StarkBatteryPayloadLayout.lengthWithDCBus
            ? Int(reader.u16(at: StarkBatteryPayloadLayout.dcBusOffset))
            : nil

        return StarkBatteryPayload(
            stateOfChargePercent: socRaw.clamped(to: StarkBatteryLimits.percentage),
            stateOfHealthPercent: stateOfHealthPercent(from: sohRaw),
            dcBusRaw: dcBusRaw
        )
    }

    private func stateOfHealthPercent(from rawValue: Int?) -> Int? {
        guard let rawValue, rawValue != StarkBatteryLimits.unknownStateOfHealth else {
            return nil
        }
        return rawValue.clamped(to: StarkBatteryLimits.percentage)
    }
}
