public struct VehicleMeasurement: Sendable, Equatable {
    public let value: Double
    public let unit: String

    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }
}
