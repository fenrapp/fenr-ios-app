public struct BikeLockCardViewState: Equatable, Sendable {
    public enum Sheet: Equatable, Sendable {
        case setup
        case enterPIN
    }

    public let isAvailable: Bool
    public let isLocked: Bool
    public let isWorking: Bool
    public let isActionEnabled: Bool
    public let isConfigured: Bool
    public let title: String
    public let statusText: String
    public let actionTitle: String
    public let detailText: String
    public let errorText: String?
    public let sheet: Sheet?

    public init(
        isAvailable: Bool = false,
        isLocked: Bool = false,
        isWorking: Bool = false,
        isActionEnabled: Bool = false,
        isConfigured: Bool = false,
        title: String = "Bike Lock",
        statusText: String = "Checking compatibility",
        actionTitle: String = "Set Up",
        detailText: String = "VCU compatibility must be verified before Bike Lock is enabled.",
        errorText: String? = nil,
        sheet: Sheet? = nil
    ) {
        self.isAvailable = isAvailable
        self.isLocked = isLocked
        self.isWorking = isWorking
        self.isActionEnabled = isActionEnabled
        self.isConfigured = isConfigured
        self.title = title
        self.statusText = statusText
        self.actionTitle = actionTitle
        self.detailText = detailText
        self.errorText = errorText
        self.sheet = sheet
    }
}
