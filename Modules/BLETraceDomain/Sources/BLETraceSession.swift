import Foundation

public enum BLETraceSessionStartReason: String, Codable, Sendable {
    case connectionRequest = "connection_request"
    case restoration
    case manualRequest = "manual_request"
}

public enum BLETraceSessionEndReason: String, Codable, Sendable {
    case userDisconnected = "user_disconnected"
    case clientStopped = "client_stopped"
    case reconnectExhausted = "reconnect_exhausted"
    case pairingResetRequired = "pairing_reset_required"
    case abruptTermination = "abrupt_termination"
    case storageLimitReached = "storage_limit_reached"
    case exportSnapshot = "export_snapshot"
    case userStopped = "user_stopped"
}

public enum BLETraceSessionStatus: String, Codable, Sendable {
    case active
    case complete
    case incomplete
    case truncated
}

public struct BLETraceSessionContext: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let startUptimeNanoseconds: UInt64
    public let reason: BLETraceSessionStartReason

    public init(
        id: UUID,
        startedAt: Date,
        startUptimeNanoseconds: UInt64,
        reason: BLETraceSessionStartReason
    ) {
        self.id = id
        self.startedAt = startedAt
        self.startUptimeNanoseconds = startUptimeNanoseconds
        self.reason = reason
    }
}

public struct BLETraceSessionSummary: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let duration: TimeInterval?
    public let fileSizeBytes: Int64
    public let eventCount: Int
    public let status: BLETraceSessionStatus
    public let fileName: String

    public init(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        duration: TimeInterval?,
        fileSizeBytes: Int64,
        eventCount: Int,
        status: BLETraceSessionStatus,
        fileName: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
        self.eventCount = eventCount
        self.status = status
        self.fileName = fileName
    }
}

public struct BLETraceEnvironment: Codable, Equatable, Sendable {
    public let appVersion: String
    public let appBuild: String
    public let operatingSystem: String
    public let deviceModel: String

    public init(appVersion: String, appBuild: String, operatingSystem: String, deviceModel: String) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.operatingSystem = operatingSystem
        self.deviceModel = deviceModel
    }
}
