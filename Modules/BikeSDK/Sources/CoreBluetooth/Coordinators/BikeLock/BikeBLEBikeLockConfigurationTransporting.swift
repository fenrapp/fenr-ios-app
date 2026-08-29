import Foundation

@MainActor
protocol BikeBLEBikeLockConfigurationTransporting: AnyObject {
    func ensureReady() throws
    func readVersions() async throws -> Data
    func readConfiguration(
        request: Data,
        operationName: String,
        allowLiveTelemetrySession: Bool
    ) async throws -> Data
    func writeConfiguration(_ payload: Data) async throws
}

extension BikeBLEVCUConfigurationTransport: BikeBLEBikeLockConfigurationTransporting {}
