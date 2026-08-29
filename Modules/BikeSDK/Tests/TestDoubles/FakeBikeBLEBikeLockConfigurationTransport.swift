@testable import BikeSDK
import Foundation
import StarkProtocol

@MainActor
final class FakeBikeBLEBikeLockConfigurationTransport: BikeBLEBikeLockConfigurationTransporting {
    private(set) var requests: [Data] = []
    private(set) var writePayloads: [Data] = []
    var versionData = Data("1.6.29".utf8)
    var configuration = StarkBikeLockConfigurationPayload(
        isLocked: false,
        lockType: 1,
        timeoutSeconds: 0
    )
    var ignoresWrites = false

    func ensureReady() throws {}

    func readVersions() async throws -> Data {
        versionData
    }

    func readConfiguration(
        request: Data,
        operationName _: String,
        allowLiveTelemetrySession _: Bool
    ) async throws -> Data {
        requests.append(request)
        return Data([
            2,
            StarkBikeLockConfigurationCommand.configurationType,
            0,
            configuration.isLocked ? 1 : 0,
            configuration.lockType,
            UInt8(truncatingIfNeeded: configuration.timeoutSeconds),
            UInt8(truncatingIfNeeded: configuration.timeoutSeconds >> 8)
        ])
    }

    func writeConfiguration(_ payload: Data) async throws {
        writePayloads.append(payload)
        guard !ignoresWrites else { return }
        configuration = .init(
            isLocked: payload[3] == 1,
            lockType: payload[4],
            timeoutSeconds: Int(Int16(littleEndian: Int16(
                bitPattern: UInt16(payload[5]) | UInt16(payload[6]) << 8
            )))
        )
    }
}
