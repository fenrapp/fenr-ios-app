public struct StarkInverterTemperaturesPayload: StarkPayload {
    public struct SensorGroup: Equatable, Sendable {
        public let rawValues: [UInt16]
        public let validStatus: UInt8
        public let usedStatus: UInt8

        public init(rawValues: [UInt16], validStatus: UInt8, usedStatus: UInt8) {
            self.rawValues = rawValues
            self.validStatus = validStatus
            self.usedStatus = usedStatus
        }
    }

    public let motor: SensorGroup
    public let igbt: SensorGroup

    public init(motor: SensorGroup, igbt: SensorGroup) {
        self.motor = motor
        self.igbt = igbt
    }

    public var rawValues: [UInt16] {
        motor.rawValues + igbt.rawValues
    }

    public var celsius: [Double?] {
        rawValues.map { rawValue in
            guard rawValue != StarkInverterTemperaturesPayloadLayout.unavailableRawValue else {
                return nil
            }
            return Double(rawValue) / StarkInverterTemperaturesPayloadLayout.temperatureScale
        }
    }
}
