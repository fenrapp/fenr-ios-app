import Foundation

extension BikeBLEVCUConfigurationTransport {
    func readVersions() async throws -> Data {
        try await withTransaction {
            let peripheral = try authenticatedPeripheral()
            let characteristic = try versionsCharacteristic()
            return try await read(
                peripheral: peripheral,
                characteristic: characteristic,
                operationName: "4001 read"
            )
        }
    }

    func readConfiguration(
        request: Data,
        operationName: String,
        allowLiveTelemetrySession: Bool = false
    ) async throws -> Data {
        try await withTransaction {
            let peripheral = try configurationReadPeripheral(
                allowLiveTelemetrySession: allowLiveTelemetrySession
            )
            let characteristic = try configurationCharacteristic()
            let expectedResponse = try BikeBLEVCUConfigurationExpectedResponse(request: request)
            let canRead = characteristic.properties.contains(.read)
            try await waitForConfigurationNotificationsIfNeeded(characteristic)
            let canReceiveNotification = characteristic.isNotifying
                || sessionStore.subscribedCharacteristics.contains(characteristic.uuid)
            guard canRead || canReceiveNotification else {
                throw BikeSDKError.operationFailed(
                    "VCU configuration 4005 cannot return a response: "
                        + "read is unavailable and notifications are not enabled"
                )
            }
            expectedConfigurationResponse = expectedResponse
            bufferedConfigurationResponse = nil
            defer {
                expectedConfigurationResponse = nil
                bufferedConfigurationResponse = nil
            }
            await emitConfigurationDebug(prefix: "Request", data: request)
            try await write(request, peripheral: peripheral, characteristic: characteristic)
            let response: Data
            if let bufferedConfigurationResponse {
                response = try bufferedConfigurationResponse.get()
            } else {
                response = try await awaitConfigurationResponse(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    operationName: operationName,
                    shouldRead: canRead
                )
            }
            await emitConfigurationDebug(prefix: "Response", data: response)
            return response
        }
    }

    func writeConfiguration(_ payload: Data) async throws {
        try await withTransaction {
            let peripheral = try authenticatedPeripheral()
            let characteristic = try configurationCharacteristic()
            guard payload.count >= 2,
                  payload[0] == 1,
                  payload[1] == 8 || payload[1] == 5
            else {
                try await write(payload, peripheral: peripheral, characteristic: characteristic)
                return
            }
            let expectedResponse = try BikeBLEVCUConfigurationExpectedResponse(
                writeRequest: payload
            )
            try await waitForConfigurationNotificationsIfNeeded(characteristic)
            expectedConfigurationResponse = expectedResponse
            bufferedConfigurationResponse = nil
            defer {
                expectedConfigurationResponse = nil
                bufferedConfigurationResponse = nil
            }
            try await write(payload, peripheral: peripheral, characteristic: characteristic)
            let response: Data
            if let bufferedConfigurationResponse {
                response = try bufferedConfigurationResponse.get()
            } else {
                response = try await awaitConfigurationResponse(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    operationName: "4005 configuration type \(payload[1]) write response",
                    shouldRead: false
                )
            }
            await emitConfigurationDebug(prefix: "Write response", data: response)
            guard response.count >= 3 else {
                throw BikeSDKError.operationFailed(
                    "VCU configuration write returned an incomplete response"
                )
            }
            guard response[2] == 0 else {
                throw BikeSDKError.operationFailed(
                    "VCU configuration write was rejected with status \(response[2])"
                )
            }
        }
    }
}
