public struct BatteryCellViewData: Equatable, Identifiable, Sendable {
    public let position: Int
    public let voltage: String
    public let deviation: String
    public let condition: BatteryCellCondition
    public let isBalancing: Bool
    public let isMinimum: Bool
    public let isMaximum: Bool

    public var id: Int { position }

    public init(
        position: Int,
        voltage: String,
        deviation: String,
        condition: BatteryCellCondition,
        isBalancing: Bool,
        isMinimum: Bool,
        isMaximum: Bool
    ) {
        self.position = position
        self.voltage = voltage
        self.deviation = deviation
        self.condition = condition
        self.isBalancing = isBalancing
        self.isMinimum = isMinimum
        self.isMaximum = isMaximum
    }
}
