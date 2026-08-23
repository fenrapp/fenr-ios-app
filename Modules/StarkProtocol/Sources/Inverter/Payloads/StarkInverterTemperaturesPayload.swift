public struct StarkInverterTemperaturesPayload: StarkPayload {
    public let rawValues: [UInt16]

    public init(rawValues: [UInt16]) {
        self.rawValues = rawValues
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
