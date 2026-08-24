import Foundation
import StarkProtocol

public struct BikeSDKChargePowerControlSnapshot: Equatable, Sendable {
    public let vcuFirmware: String?
    public let isFirmwareCompatible: Bool
    public let readRequestHex: String
    public let readResponseHex: String
    public let parsedConfig: StarkChargerConfiguration
    public let lastWriteHex: String?
    public let didPassNoOpWrite: Bool
    public let logLines: [String]

    public init(
        vcuFirmware: String?,
        isFirmwareCompatible: Bool,
        readRequestHex: String,
        readResponseHex: String,
        parsedConfig: StarkChargerConfiguration,
        lastWriteHex: String?,
        didPassNoOpWrite: Bool,
        logLines: [String]
    ) {
        self.vcuFirmware = vcuFirmware
        self.isFirmwareCompatible = isFirmwareCompatible
        self.readRequestHex = readRequestHex
        self.readResponseHex = readResponseHex
        self.parsedConfig = parsedConfig
        self.lastWriteHex = lastWriteHex
        self.didPassNoOpWrite = didPassNoOpWrite
        self.logLines = logLines
    }
}
