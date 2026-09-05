import Foundation

enum BikeSDKText {
    static let disconnectedByUser = "Disconnected by user"
    static let connectFailed = "Failed to connect"
    static let connectionTimedOut = "Bike connection timed out"
    static let connectionAlreadyActive = "A bike connection is already active"
    static let characteristicTitle = "Characteristic"
    static let serviceTitle = "Service"
    static let descriptorTitle = "Descriptor"
    static let pairingTitle = "Pairing"
    static let pairingResetRequired =
        "Forget this bike in iPhone Settings > Bluetooth, then reconnect to create a new pairing."
    static let securityTitle = "Security"
    static let readTitle = "Read"
    static let subscriptionTitle = "Subscription"
    static let securityAlreadyRunning = "Security authentication already running"
    static let securityAlreadyAuthenticated = "Security session already authenticated"
    static let manualSecurityRetry = "Manual security retry"
    static let securityChallenge = "Security challenge"
    static let securityChallengeGuidance =
        "Accept the Bluetooth pairing prompt on Watch or iPhone; authentication will retry automatically"
    static let securityCharacteristicMissing = "Security characteristic 00001001 is unavailable"
    static let securityServiceMissing = "Security service 00001000 is unavailable"
    static let securityCCCDMissing = "Security characteristic is missing CCCD"
    static let securityPropertiesInvalid = "Security characteristic does not support read, write and notify"
    static let securityNotificationsEnabled = "Security notifications enabled"
    static let securityNotificationsDisabled = "Security notifications disabled"
    static let securityNonceRead = "Reading 32-byte security nonce"
    static let securityNonceReceived = "Security nonce received: 32 bytes"
    static let securityPayloadWritten = "V2 response written; waiting for authentication result"
    static let securityAuthenticated = "Stark security authenticated"
    static let securityUpdateIgnored = "Ignored security update outside the active handshake"
    static let securityAuthenticationFailed = "Stark security rejected the response"
    static let telemetryQueued = "Telemetry subscription queued until Stark authentication succeeds"
    static let telemetryNotifyUnavailable = "Telemetry characteristic does not support notifications"
    static let unexpectedNotificationState = "Ignored notification state for a non-active characteristic"
    static let requiredServicesMissing = "Required diagnostics services missing"
    static let requiredCharacteristicsMissing = "Required diagnostics characteristics missing"
    static let authenticationRequired = "Stark authentication must succeed before reading telemetry"
    static let noActivePeripheral = "No active peripheral"
    static let noReadableCharacteristics = "No readable telemetry characteristic is available"
    static let noProperties = "noProperties"
    static let noDescriptors = "noDescriptors"
}

public enum BikePowerModeDebugLog {
    public static let launchArgument = "-debugPowerModeLogs"

    public static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
            || ProcessInfo.processInfo.environment["FENR_POWER_MODE_LOGS"] == "1"
        #else
        false
        #endif
    }

    public static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let timestamp = Date().formatted(
            .dateTime
                .locale(Locale(identifier: "en_US_POSIX"))
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .secondFraction(.fractional(3))
        )
        print("[PowerModes][\(timestamp)] \(message())")
    }
}
