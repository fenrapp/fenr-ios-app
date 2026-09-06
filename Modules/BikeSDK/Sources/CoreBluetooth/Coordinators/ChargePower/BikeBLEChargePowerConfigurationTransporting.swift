import Foundation

@MainActor
protocol BikeBLEChargePowerConfigurationTransporting: AnyObject {
    func readVersions() async throws -> Data
    func readConfiguration(
        request: Data,
        operationName: String,
        allowLiveTelemetrySession: Bool
    ) async throws -> Data
    func writeConfiguration(_ payload: Data) async throws
}

extension BikeBLEVCUConfigurationTransport: BikeBLEChargePowerConfigurationTransporting {}
