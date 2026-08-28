import BikeDomain
import SettingsDomain

public struct PowerModeSettingsMappingInput: Sendable {
    public let telemetry: BikeTelemetry
    public let connection: BikeConnection
    public let settings: AppSettings
    public let profile: BikeProfile?
    public let selectedMapIndex: Int
    public let isRefreshing: Bool
    public let refreshError: String?
    public let nameError: String?
    public let isPreparingControl: Bool
    public let isApplyingControl: Bool
    public let isBaseControlReady: Bool
    public let isTractionControlReady: Bool
    public let controlMessage: String?
    public let controlError: String?

    public init(
        telemetry: BikeTelemetry,
        connection: BikeConnection,
        settings: AppSettings,
        profile: BikeProfile?,
        selectedMapIndex: Int,
        isRefreshing: Bool,
        refreshError: String?,
        nameError: String?,
        isPreparingControl: Bool = false,
        isApplyingControl: Bool = false,
        isBaseControlReady: Bool = false,
        isTractionControlReady: Bool = false,
        controlMessage: String? = nil,
        controlError: String? = nil
    ) {
        self.telemetry = telemetry
        self.connection = connection
        self.settings = settings
        self.profile = profile
        self.selectedMapIndex = selectedMapIndex
        self.isRefreshing = isRefreshing
        self.refreshError = refreshError
        self.nameError = nameError
        self.isPreparingControl = isPreparingControl
        self.isApplyingControl = isApplyingControl
        self.isBaseControlReady = isBaseControlReady
        self.isTractionControlReady = isTractionControlReady
        self.controlMessage = controlMessage
        self.controlError = controlError
    }
}
