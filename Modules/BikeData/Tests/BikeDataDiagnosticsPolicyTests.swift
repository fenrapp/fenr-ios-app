@testable import BikeData
import BikeDomain
import BikeSDK
import Testing

@Suite("Bike data manual diagnostics")
struct BikeDataDiagnosticsPolicyTests {
    @Test("Disabled diagnostics preserve telemetry without queuing technical events")
    func disabledDiagnosticsPreserveTelemetry() async {
        let client = FakeBikeTelemetryClient()
        let capture = DiagnosticsCaptureSwitch()
        let repository = makeRepository(client: client, diagnosticsEnabled: { capture.isEnabled })
        await repository.start()
        let debugStream = await repository.observeDebugEvents()
        var debug = debugStream.makeAsyncIterator()
        let telemetryStream = await repository.observeTelemetry()
        var telemetry = telemetryStream.makeAsyncIterator()
        _ = await telemetry.next()
        await client.send(.debug(.init(title: "Ignored", detail: "Capture is disabled")))
        await client.send(.rssi(-45))
        await client.send(.telemetry(BikeDataTelemetryFixtures.battery))
        let battery = await telemetry.next()
        #expect(battery?.batteryLevel == .known(percent: 76))

        capture.enable()
        await client.send(.debug(.init(title: "Manual", detail: "Capture is enabled")))
        let event = await debug.next()
        #expect(event?.title == "Manual")
        await repository.stop()
    }

}
