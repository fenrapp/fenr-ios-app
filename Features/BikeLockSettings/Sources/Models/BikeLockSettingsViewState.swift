import SettingsDomain

public struct BikeLockSettingsViewState: Equatable, Sendable {
    public let isAvailable: Bool
    public let currentMode: BikeLockSecurityMode
    public let isWorking: Bool
    public let errorMessage: String?
    public let destination: BikeLockSettingsDestination?

    public init(
        isAvailable: Bool = false,
        currentMode: BikeLockSecurityMode = .notConfigured,
        isWorking: Bool = false,
        errorMessage: String? = nil,
        destination: BikeLockSettingsDestination? = nil
    ) {
        self.isAvailable = isAvailable
        self.currentMode = currentMode
        self.isWorking = isWorking
        self.errorMessage = errorMessage
        self.destination = destination
    }

    public var currentModeTitle: String { currentMode.title }
    public var canChangePIN: Bool { currentMode.requiresPIN }
}

public extension BikeLockSecurityMode {
    var title: String {
        switch self {
        case .notConfigured: "Not set up"
        case .withoutPIN: "No PIN"
        case .pin: "PIN"
        case .pinAndFaceID: "PIN + Face ID"
        }
    }
}
