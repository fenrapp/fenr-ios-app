@testable import BikeSDK
import Foundation
import RuntimeConfiguration
import Testing

@Suite("Bike SDK runtime configuration")
struct BikeSDKRuntimeConfigurationTests {
    @Test("Connection timeout defaults to the observed VargPilot watchdog interval")
    func connectionTimeoutUsesObservedInterval() {
        let configuration = BikeSDKRuntimeConfiguration()

        #expect(configuration.connectionOperationTimeout == .seconds(12))
    }

    @Test("Reconnect policy is configurable")
    func reconnectPolicyIsConfigurable() {
        let expectedPolicy = BikeBLEReconnectPolicy(delays: [.seconds(2), .seconds(3)])
        let configuration = BikeSDKRuntimeConfiguration(reconnectPolicy: expectedPolicy)

        #expect(configuration.reconnectPolicy == expectedPolicy)
    }

    @Test("CoreBluetooth restoration identifier is stable without bluetooth-central background mode")
    func coreBluetoothRestorationIdentifierIsStableWithoutBackgroundMode() throws {
        let bundle = try makeBundle(backgroundModes: [])

        #expect(
            CoreBluetoothRestorationPolicy.restorationIdentifier(for: bundle)
                == FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
        )
    }

    @Test("CoreBluetooth restoration identifier is stable with bluetooth-central background mode")
    func coreBluetoothRestorationIdentifierIsStableWithBackgroundMode() throws {
        let bundle = try makeBundle(
            backgroundModes: [FENRRuntimeConstants.BikeSDK.bluetoothCentralBackgroundMode]
        )

        #expect(
            CoreBluetoothRestorationPolicy.restorationIdentifier(for: bundle)
                == FENRRuntimeConstants.BikeSDK.centralRestorationIdentifier
        )
    }

    private func makeBundle(backgroundModes: [String]) throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [
            FENRRuntimeConstants.BikeSDK.backgroundModesInfoPlistKey: backgroundModes
        ], format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("Info.plist"))
        return try #require(Bundle(url: directory))
    }
}
