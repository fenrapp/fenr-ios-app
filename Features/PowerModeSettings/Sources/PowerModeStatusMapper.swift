import BikeDomain
import Foundation

struct PowerModeStatusMapper: Sendable {
    func operationStatus(
        configuration: BikePowerModeConfiguration?,
        isTractionControlReady: Bool,
        input: PowerModeSettingsMappingInput
    ) -> PowerModeOperationStatus {
        if input.isRefreshing {
            return .init(
                text: String(localized: .powerModeSettingsReadingStatus),
                phase: .refreshing
            )
        }
        if let refreshError = input.refreshError {
            return .init(text: refreshError, phase: .error)
        }
        if let controlError = input.controlError {
            return .init(text: controlError, phase: .error)
        }
        if input.isApplyingControl {
            return .init(
                text: String(localized: .powerModeSettingsApplyingStatus),
                phase: .applying
            )
        }
        if input.isPreparingControl {
            return .init(
                text: String(localized: .powerModeSettingsVerifyingSafetyStatus),
                phase: .preparing
            )
        }
        guard configuration?.hasBaseConfiguration == true else {
            return .init(
                text: String(localized: .powerModeSettingsWaitingForMapDataStatus),
                phase: .waiting
            )
        }
        if let controlMessage = input.controlMessage {
            return .init(text: controlMessage, phase: .confirmed)
        }
        if input.isBaseControlReady {
            let text = isTractionControlReady
                ? String(localized: .powerModeSettingsAllControlsReady)
                : String(localized: .powerModeSettingsBaseControlsReady)
            return .init(text: text, phase: .ready)
        }
        return .init(
            text: String(localized: .powerModeSettingsWriteVerificationRequired),
            phase: .verification
        )
    }

    func status(
        connectionState: ConnectionState,
        connection: PowerModeConnectionPresentation,
        operation: PowerModeOperationStatus,
        isActivity: Bool
    ) -> PowerModeStatusViewData {
        let detail = [operation.text, connection.capability]
            .formatted(.list(type: .and, width: .narrow))
        if operation.isError {
            return status(
                connection.title,
                detail: detail,
                icon: "exclamationmark.triangle.fill",
                emphasis: .critical
            )
        }
        if isActivity {
            return status(
                connection.title,
                detail: detail,
                icon: operation.systemImage,
                emphasis: .informational,
                isActivity: true
            )
        }
        return connectionStatus(
            state: connectionState,
            connection: connection,
            detail: detail,
            operation: operation
        )
    }

    func connectionText(_ state: ConnectionState) -> String {
        switch state {
        case .receivingTelemetry: String(localized: .powerModeSettingsBikeConnected)
        case .authenticated, .subscribed: String(localized: .powerModeSettingsBikeAuthenticated)
        case .scanning, .connecting, .discovering, .authenticating, .reconnecting:
            String(localized: .powerModeSettingsConnectingToBike)
        case .bluetoothPoweredOff: String(localized: .powerModeSettingsBluetoothOff)
        case .bluetoothUnauthorized: String(localized: .powerModeSettingsBluetoothAccessRequired)
        case .bluetoothUnavailable: String(localized: .powerModeSettingsBluetoothUnavailable)
        case .pairingResetRequired: String(localized: .powerModeSettingsPairingResetRequired)
        case .failed: String(localized: .powerModeSettingsConnectionFailed)
        case .disconnected: String(localized: .powerModeSettingsBikeDisconnected)
        case .idle: String(localized: .powerModeSettingsBikeUnavailable)
        }
    }

    func capabilityText(
        detectedTier: BikeDetectedPowerTier,
        declaredTier: BikeDeclaredPowerTier?
    ) -> String {
        if case .alpha = detectedTier {
            return String(localized: .powerModeSettingsAlphaCapabilityDetected)
        }
        if declaredTier == .alpha {
            return String(localized: .powerModeSettingsAlphaVerificationPending)
        }
        return String(localized: .powerModeSettingsStandardBaseline)
    }

    func isAuthenticated(_ state: ConnectionState) -> Bool {
        switch state {
        case .authenticated, .subscribed, .receivingTelemetry: true
        default: false
        }
    }

    private func connectionStatus(
        state: ConnectionState,
        connection: PowerModeConnectionPresentation,
        detail: String,
        operation: PowerModeOperationStatus
    ) -> PowerModeStatusViewData {
        switch state {
        case .scanning, .connecting, .discovering, .authenticating, .reconnecting:
            status(
                connection.title,
                detail: detail,
                icon: "antenna.radiowaves.left.and.right",
                emphasis: .informational,
                isActivity: true
            )
        case .bluetoothPoweredOff, .bluetoothUnauthorized, .bluetoothUnavailable,
             .pairingResetRequired, .failed:
            status(
                connection.title,
                detail: detail,
                icon: "exclamationmark.triangle.fill",
                emphasis: .critical
            )
        case .disconnected:
            status(
                connection.title,
                detail: detail,
                icon: "bolt.slash.fill",
                emphasis: .warning
            )
        case .idle:
            status(connection.title, detail: detail, icon: "motorcycle", emphasis: .neutral)
        case .authenticated, .subscribed, .receivingTelemetry:
            status(
                connection.title,
                detail: detail,
                icon: operation.systemImage,
                emphasis: operation.emphasis
            )
        }
    }

    private func status(
        _ title: String,
        detail: String,
        icon: String,
        emphasis: PowerModeStatusEmphasis,
        isActivity: Bool = false
    ) -> PowerModeStatusViewData {
        .init(
            title: title,
            detail: detail,
            systemImage: icon,
            emphasis: emphasis,
            isActivity: isActivity
        )
    }
}

struct PowerModeOperationStatus {
    enum Phase: Equatable {
        case refreshing
        case error
        case applying
        case preparing
        case waiting
        case confirmed
        case ready
        case verification
    }

    let text: String
    let phase: Phase

    var isError: Bool { phase == .error }

    var emphasis: PowerModeStatusEmphasis {
        switch phase {
        case .confirmed, .ready: .positive
        case .waiting, .verification: .warning
        case .refreshing, .applying, .preparing: .informational
        case .error: .critical
        }
    }

    var systemImage: String {
        switch phase {
        case .refreshing: "arrow.clockwise"
        case .error: "exclamationmark.triangle.fill"
        case .applying: "slider.horizontal.3"
        case .preparing, .verification: "checkmark.shield"
        case .waiting: "wave.3.right"
        case .confirmed, .ready: "checkmark.circle.fill"
        }
    }
}
