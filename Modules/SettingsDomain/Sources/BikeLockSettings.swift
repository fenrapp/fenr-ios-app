public enum BikeLockSecurityMode: String, Codable, CaseIterable, Sendable {
    case notConfigured
    case withoutPIN
    case pin
    case pinAndFaceID

    public var isConfigured: Bool {
        self != .notConfigured
    }

    public var requiresPIN: Bool {
        self == .pin || self == .pinAndFaceID
    }
}

public struct BikeLockSettings: Codable, Equatable, Sendable {
    public var securityMode: BikeLockSecurityMode

    public init(securityMode: BikeLockSecurityMode = .notConfigured) {
        self.securityMode = securityMode
    }
}
