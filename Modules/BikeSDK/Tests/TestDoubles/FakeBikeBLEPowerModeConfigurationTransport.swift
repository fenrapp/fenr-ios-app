@testable import BikeSDK
import Foundation
import StarkProtocol

@MainActor
final class FakeBikeBLEPowerModeConfigurationTransport: BikeBLEPowerModeConfigurationTransporting {
    private(set) var requests: [Data] = []
    private(set) var writePayloads: [Data] = []
    private(set) var allowedLiveTelemetrySessionValues: [Bool] = []
    var failingRequests = Set<Data>()
    var versionData = Data("1.12.0".utf8)
    var curveOverrides: [UInt8: UInt8] = [:]
    var writeError: (any Error)?
    var isDesynchronized = false
    var desynchronizesOnReadFailure = false
    var tractionReadFailuresRemaining = 0
    var tractionReadError: (any Error)?
    var queuedTractionResponses: [Data] = []
    var ignoresTractionWrites = false
    var onVersions: (() -> Void)?
    var onTractionRead: (() -> Void)?

    private var powerResponses: [UInt8: Data] = [:]
    private var tractionResponses: [UInt8: Data] = [:]

    func ensureReady() throws {
        if isDesynchronized { throw BikeSDKError.operationFailed("Synthetic desynchronization") }
    }

    func readVersions() async throws -> Data {
        onVersions?()
        return versionData
    }

    func readConfiguration(
        request: Data,
        operationName: String,
        allowLiveTelemetrySession: Bool
    ) async throws -> Data {
        requests.append(request)
        allowedLiveTelemetrySessionValues.append(allowLiveTelemetrySession)
        guard !failingRequests.contains(request) else {
            throw BikeSDKError.operationFailed("Simulated 4005 failure")
        }
        let mapIndex = request[2]
        switch request[1] {
        case 0:
            return powerResponses[mapIndex]
                ?? Data([
                    2, 0, 0, mapIndex, 75, 0, 50, 0,
                    curveOverrides[mapIndex] ?? 0, 0
                ])
        case 8:
            onTractionRead?()
            if tractionReadFailuresRemaining > 0 {
                tractionReadFailuresRemaining -= 1
                isDesynchronized = desynchronizesOnReadFailure
                throw tractionReadError ?? BikeSDKError.operationFailed("Synthetic timeout")
            }
            if !queuedTractionResponses.isEmpty { return queuedTractionResponses.removeFirst() }
            return tractionResponses[mapIndex]
                ?? Data([2, 8, 0, mapIndex, 200, 0, 200, 0])
        default:
            throw BikeSDKError.operationFailed("Unsupported fake 4005 request")
        }
    }

    func writeConfiguration(_ payload: Data) async throws {
        writePayloads.append(payload)
        if let writeError { throw writeError }
        guard !payload.isEmpty, payload[0] == 1 else {
            throw BikeSDKError.operationFailed("Unsupported fake 4005 write")
        }
        switch payload[1] {
        case StarkPowerModeConfigurationCommand.configurationType:
            guard payload.count == StarkPowerModeConfigurationCommand.writePacketLength else {
                throw BikeSDKError.operationFailed("Unsupported fake base-map write")
            }
            let mapIndex = payload[2]
            powerResponses[mapIndex] = Data([
                2, 0, 0, mapIndex,
                payload[4], payload[5], payload[6], payload[7],
                curveOverrides[mapIndex] ?? 0, 0
            ])
        case StarkTractionControlConfigurationCommand.configurationType:
            guard payload.count == StarkTractionControlConfigurationCommand.writePacketLength,
                  payload[4] == StarkTractionControlConfigurationCommand.writeMode
            else {
                throw BikeSDKError.operationFailed("Unsupported fake traction-control write")
            }
            let mapIndex = payload[3]
            if ignoresTractionWrites { return }
            tractionResponses[mapIndex] = Data([
                2, 8, 0, mapIndex,
                payload[5], payload[6], payload[7], payload[8]
            ])
        default:
            throw BikeSDKError.operationFailed("Unsupported fake 4005 write type")
        }
    }
}
