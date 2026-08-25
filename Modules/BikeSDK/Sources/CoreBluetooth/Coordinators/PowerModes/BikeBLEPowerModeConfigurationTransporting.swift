import Foundation

@MainActor
protocol BikeBLEPowerModeConfigurationTransporting: AnyObject {
    func readConfiguration(
        request: Data,
        operationName: String,
        allowLiveTelemetrySession: Bool
    ) async throws -> Data
}

extension BikeBLEVCUConfigurationTransport: BikeBLEPowerModeConfigurationTransporting {}
