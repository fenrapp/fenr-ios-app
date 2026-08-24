@testable import BikeSDK
import Foundation
import RuntimeConfiguration
import Testing

@Suite("Bike SDK runtime configuration")
struct BikeSDKRuntimeConfigurationTests {
    @Test("Reconnect policy is configurable")
    func reconnectPolicyIsConfigurable() {
        let expectedPolicy = BikeBLEReconnectPolicy(delays: [.seconds(2), .seconds(3)])
        let configuration = BikeSDKRuntimeConfiguration(reconnectPolicy: expectedPolicy)

        #expect(configuration.reconnectPolicy == expectedPolicy)
    }

    @Test("CoreBluetooth restoration is disabled without bluetooth-central background mode")
    func coreBluetoothRestorationRequiresBackgroundMode() throws {
        let bundle = try makeBundle(backgroundModes: [])

        #expect(CoreBluetoothRestorationPolicy.restorationIdentifier(for: bundle) == nil)
    }

    @Test("CoreBluetooth restoration is enabled with bluetooth-central background mode")
    func coreBluetoothRestorationUsesIdentifierWhenBackgroundModeIsPresent() throws {
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
