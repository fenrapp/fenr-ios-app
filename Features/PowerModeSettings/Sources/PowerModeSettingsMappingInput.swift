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
    let pendingAdjustmentValue: Double?
    let recentAdjustmentResult: PowerModeAdjustmentResult?
    let isBaseControlReady: Bool
    let isTractionFirmwareIncompatible: Bool
    let isTractionControlReady: Bool
    let tractionPower: Double?
    let tractionBraking: Double?
    let allowsTractionRecommit: Bool
    let isTractionBusy: Bool
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
        pendingAdjustmentValue: Double? = nil,
        recentAdjustmentResult: PowerModeAdjustmentResult? = nil,
        isBaseControlReady: Bool = false,
        isTractionControlReady: Bool = false,
        isTractionFirmwareIncompatible: Bool = false,
        tractionPower: Double? = nil,
        tractionBraking: Double? = nil,
        allowsTractionRecommit: Bool = false,
        isTractionBusy: Bool = false,
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
        self.pendingAdjustmentValue = pendingAdjustmentValue
        self.recentAdjustmentResult = recentAdjustmentResult
        self.isBaseControlReady = isBaseControlReady
        self.isTractionFirmwareIncompatible = isTractionFirmwareIncompatible
        self.isTractionControlReady = isTractionControlReady
        self.tractionPower = tractionPower
        self.tractionBraking = tractionBraking
        self.allowsTractionRecommit = allowsTractionRecommit
        self.isTractionBusy = isTractionBusy
        self.controlMessage = controlMessage
        self.controlError = controlError
        self.isCanonicalTelemetryAvailable = isCanonicalTelemetryAvailable
    }
}

enum PowerModeAdjustmentResult: Equatable, Sendable {
    case confirmed(PowerModeAdjustmentID)
    case failed(PowerModeAdjustmentID, message: String)
}
