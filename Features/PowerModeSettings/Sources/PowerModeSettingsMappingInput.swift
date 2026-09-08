import BikeDomain
import Foundation
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
    let isSavingName: Bool
    let nameSaveCompletionID: UUID?
    let nameError: String?
    let isPreparingControl: Bool
    let isApplyingControl: Bool
    let activeAdjustmentID: PowerModeAdjustmentID?
    let recentAdjustmentResult: PowerModeAdjustmentResult?
    let isBaseControlReady: Bool
    let isTractionControlReady: Bool
    let controlMessage: String?
    let controlError: String?
    let isCanonicalTelemetryAvailable: Bool

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
        isSavingName: Bool = false,
        nameSaveCompletionID: UUID? = nil,
        isPreparingControl: Bool = false,
        isApplyingControl: Bool = false,
        activeAdjustmentID: PowerModeAdjustmentID? = nil,
        recentAdjustmentResult: PowerModeAdjustmentResult? = nil,
        isBaseControlReady: Bool = false,
        isTractionControlReady: Bool = false,
        controlMessage: String? = nil,
        controlError: String? = nil,
        isCanonicalTelemetryAvailable: Bool = false
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
        self.isSavingName = isSavingName
        self.nameSaveCompletionID = nameSaveCompletionID
        self.isPreparingControl = isPreparingControl
        self.isApplyingControl = isApplyingControl
        self.activeAdjustmentID = activeAdjustmentID
        self.recentAdjustmentResult = recentAdjustmentResult
        self.isBaseControlReady = isBaseControlReady
        self.isTractionControlReady = isTractionControlReady
        self.controlMessage = controlMessage
        self.controlError = controlError
        self.isCanonicalTelemetryAvailable = isCanonicalTelemetryAvailable
    }
}

enum PowerModeAdjustmentResult: Equatable, Sendable {
    case confirmed(PowerModeAdjustmentID)
    case failed(PowerModeAdjustmentID, message: String)
}
