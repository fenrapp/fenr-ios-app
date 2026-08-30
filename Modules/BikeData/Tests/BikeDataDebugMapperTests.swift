@testable import BikeData
import BikeSDK
import Foundation
import Testing

@Suite("Bike data diagnostic redaction")
struct BikeDataDebugMapperTests {
    @Test("Connection diagnostics keep semantic progress without bike identifiers")
    func connectionDiagnosticsAreRedacted() {
        let mapper = BikeSDKConnectionStatusDebugMapper()
        let vin = "FENRTEST000000001"
        let peripheralName = "Private Bike"
        let cases: [(BikeSDKConnectionStatus, String)] = [
            (.scanning(vin: vin), "Scanning for bike"),
            (.connecting(vin: vin, peripheralName: peripheralName), "Connecting to bike"),
            (.discovering(peripheralName: peripheralName), "Discovering bike"),
            (.authenticating(peripheralName: peripheralName), "Authenticating bike"),
            (.authenticated(peripheralName: peripheralName), "Authenticated bike"),
            (.subscribed(peripheralName: peripheralName), "Subscribed to bike"),
            (.receivingTelemetry(peripheralName: peripheralName), "Receiving telemetry"),
            (.reconnecting(vin: vin, attempt: 2, maximumAttempts: 5), "Reconnecting (2/5)")
        ]

        for (status, expected) in cases {
            let detail = mapper.map(status)
            #expect(detail == expected)
            #expect(!detail.contains(vin))
            #expect(!detail.contains(peripheralName))
        }
    }

    @Test("Peripheral and notification diagnostics omit identifiers but retain bytes")
    func eventDiagnosticsAreRedacted() {
        let mapper = makeEventMapper()
        let identifier = UUID(uuidString: "00006009-5374-6172-4B20-467574757265")!
        let peripheral = mapper.peripheralDebug(name: "Private Bike", identifier: identifier)
        let notification = mapper.notificationDebug(.init(
            characteristic: identifier,
            byteCount: 2,
            hex: "19 00",
            decodedDetail: "currentCandidateRaw=25",
            date: Date(timeIntervalSince1970: 10)
        ))

        #expect(peripheral.detail == "Peripheral discovered")
        #expect(!peripheral.detail.contains("Private Bike"))
        #expect(!peripheral.detail.contains(identifier.uuidString))
        #expect(notification.id == identifier)
        #expect(notification.detail == "2b 19 00 decoded={currentCandidateRaw=25}")
        #expect(!notification.detail.contains(identifier.uuidString))
    }

    private func makeEventMapper() -> BikeSDKEventToDomainMapper {
        BikeSDKEventToDomainMapper(
            connectionMapper: .init(),
            connectionDebugMapper: .init(),
            notificationDebugMapper: .init()
        )
    }
}
