public struct BikeLockSettingsViewState: Equatable, Sendable {
    public let isAvailable: Bool
    public let currentModeTitle: String
    public let canChangePIN: Bool
    public let protectionOptions: [BikeLockProtectionOptionViewData]
    public let isWorking: Bool
    public let errorMessage: String?
    public let destination: BikeLockSettingsDestination?

    public init(
        isAvailable: Bool = false,
        currentModeTitle: String = "Not set up",
        canChangePIN: Bool = false,
        protectionOptions: [BikeLockProtectionOptionViewData] = [],
        isWorking: Bool = false,
        errorMessage: String? = nil,
        destination: BikeLockSettingsDestination? = nil
    ) {
        self.isAvailable = isAvailable
        self.currentModeTitle = currentModeTitle
        self.canChangePIN = canChangePIN
        self.protectionOptions = protectionOptions
        self.isWorking = isWorking
        self.errorMessage = errorMessage
        self.destination = destination
    }
}
