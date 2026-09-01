public enum BatteryPackCapacity: String, Codable, CaseIterable, Sendable {
    case sixPointEightKilowattHours
    case sevenPointTwoKilowattHours

    public var wattHours: Double {
        switch self {
        case .sixPointEightKilowattHours: 6_800
        case .sevenPointTwoKilowattHours: 7_200
        }
    }
}
