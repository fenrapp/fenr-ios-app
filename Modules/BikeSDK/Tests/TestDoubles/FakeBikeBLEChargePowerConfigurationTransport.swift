@testable import BikeSDK
import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
final class FakeBikeBLEChargePowerConfigurationTransport:
    BikeBLEChargePowerConfigurationTransporting {
    private(set) var requests: [Data] = []
    private(set) var writePayloads: [Data] = []
    var versionData = Data("1.12.0".utf8)
    var response = Data([
        0x02, 0x04, 0x00,
        0x14, 0x00,
        0xE4, 0x0C,
        0xE8, 0x03,
        0x14, 0x00,
        0x02, 0x00,
        0x10, 0x00,
        0xE4, 0x0C,
        0xE4, 0x0C
    ])
    var ignoresWrites = false
    var staleReadCountAfterWrite = 0
    private var queuedReadResponses: [Data] = []

    func ensureReady() throws {}

    func readVersions() async throws -> Data {
        versionData
    }

    func readConfiguration(
        request: Data,
        operationName: String,
        allowLiveTelemetrySession: Bool
    ) async throws -> Data {
        requests.append(request)
        if !queuedReadResponses.isEmpty {
            return queuedReadResponses.removeFirst()
        }
        return response
    }

    func writeConfiguration(_ payload: Data) async throws {
        writePayloads.append(payload)
        guard !ignoresWrites else { return }
        let staleResponse = response
        guard payload.count == StarkChargerConfigurationCommand.writePacketLength,
              payload[0] == 1,
              payload[1] == StarkChargerConfigurationCommand.configurationType
        else {
            throw BikeSDKError.operationFailed("Unsupported fake charger configuration write")
        }
        response = Data([
            0x02, 0x04, 0x00,
            payload[3], payload[4],
            payload[5], payload[6],
            payload[7], payload[8],
            0x14, 0x00,
            0x02, 0x00,
            0x10, 0x00,
            payload[9], payload[10],
            payload[11], payload[12]
        ])
        queuedReadResponses.append(contentsOf: Array(
            repeating: staleResponse,
            count: staleReadCountAfterWrite
        ))
    }

    func completeWriteIfNeeded(characteristic: CBCharacteristic, error: Error?) {}

    func completeReadIfNeeded(characteristic: CBCharacteristic, error: Error?) -> Bool {
        false
    }
}

struct ImmediateBikeBLEChargePowerVerificationWaiter: BikeBLEChargePowerVerificationWaiting {
    func wait() async throws {}
}
