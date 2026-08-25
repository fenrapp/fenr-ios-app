@testable import BikeSDK
import Foundation

@MainActor
final class FakeBikeBLEPowerModeConfigurationTransport: BikeBLEPowerModeConfigurationTransporting {
    private(set) var requests: [Data] = []
    private(set) var allowedLiveTelemetrySessionValues: [Bool] = []
    var failingRequests = Set<Data>()

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
            return Data([2, 0, 0, mapIndex, 75, 0, 50, 0, 0, 0])
        case 8:
            return Data([2, 8, 0, mapIndex, 200, 0, 200, 0])
        default:
            throw BikeSDKError.operationFailed("Unsupported fake 4005 request")
        }
    }
}
