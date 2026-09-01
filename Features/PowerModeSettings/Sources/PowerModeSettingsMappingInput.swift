import BikeDomain
import SettingsDomain

struct PowerModeSettingsMappingInput: Sendable {
    let telemetry: BikeTelemetry
    let connection: BikeConnection
    let settings: AppSettings
    let profile: BikeProfile?
    let selectedMapIndex: Int
    let isStarted: Bool
    let isRefreshing: Bool
    let refreshError: String?
    let nameError: String?
    let isPreparingControl: Bool
    let isApplyingControl: Bool
    let isBaseControlReady: Bool
    let isTractionControlReady: Bool
    let controlMessage: String?
    let controlError: String?

    init(
        telemetry: BikeTelemetry,
        connection: BikeConnection,
        settings: AppSettings,
        profile: BikeProfile?,
        selectedMapIndex: Int,
        isStarted: Bool = true,
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
        self.isStarted = isStarted
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
