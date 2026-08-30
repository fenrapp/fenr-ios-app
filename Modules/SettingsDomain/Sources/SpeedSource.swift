public enum SpeedSource: String, Codable, CaseIterable, Sendable {
    case motorcycle
    case gps
    case hybrid

    public var usesDeviceLocation: Bool {
        self != .motorcycle
    }
}
