import CoreBluetooth
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
    func completeWriteIfNeeded(characteristic: CBCharacteristic, error: Error?)
    func completeReadIfNeeded(characteristic: CBCharacteristic, error: Error?) -> Bool
}

extension BikeBLEVCUConfigurationTransport: BikeBLEChargePowerConfigurationTransporting {}
