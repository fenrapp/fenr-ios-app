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
        title: String? = nil,
        statusText: String? = nil,
        actionTitle: String? = nil,
        detailText: String? = nil,
        errorText: String? = nil,
        sheet: Sheet? = nil
    ) {
        self.isAvailable = isAvailable
        self.isLocked = isLocked
        self.isWorking = isWorking
        self.isActionEnabled = isActionEnabled
        self.isConfigured = isConfigured
        self.title = title ?? rideDashboardLocalized(.rideDashboardBikeLockTitle)
        self.statusText = statusText
            ?? rideDashboardLocalized(.rideDashboardBikeLockStatusCheckingCompatibility)
        self.actionTitle = actionTitle ?? rideDashboardLocalized(.rideDashboardBikeLockActionSetUp)
        self.detailText = detailText
            ?? rideDashboardLocalized(.rideDashboardBikeLockDetailCompatibilityRequired)
        self.errorText = errorText
        self.sheet = sheet
    }
}
