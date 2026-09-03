import BikeDomain
@testable import RideDashboard
import Testing

@Suite("Ride dashboard connection mapper")
struct RideDashboardConnectionMapperTests {
    @Test("Connection failures do not expose transport details")
    func hidesConnectionFailureDetails() {
        let mapper = RideDashboardConnectionMapper()

        #expect(
            mapper.text(.idle)
                == String(localized: .rideDashboardConnectionDisconnected)
        )
        #expect(
            mapper.text(.failed(message: "transport detail"))
                == String(localized: .rideDashboardConnectionFailed)
        )
        #expect(
            mapper.text(.disconnected(reason: "transport detail"))
                == String(localized: .rideDashboardConnectionDisconnected)
        )
        #expect(
            mapper.text(.pairingResetRequired(message: "transport detail"))
                == String(localized: .rideDashboardConnectionPairingResetRequired)
        )
    }

    @Test("Only active connection phases show progress")
    func mapsRetryAndProgressStates() {
        let mapper = RideDashboardConnectionMapper()
        let retryStates: [ConnectionState] = [
            .idle,
            .bluetoothUnavailable,
            .bluetoothUnauthorized,
            .bluetoothPoweredOff,
            .pairingResetRequired(message: "reset"),
            .disconnected(reason: "disconnected"),
            .failed(message: "failed")
        ]
        let progressStates: [ConnectionState] = [
            .scanning(vin: "FENRTEST000000001"),
            .connecting(vin: "FENRTEST000000001", peripheralName: nil),
            .discovering(peripheralName: nil),
            .authenticating(peripheralName: nil),
            .authenticated(peripheralName: nil),
            .subscribed(peripheralName: nil),
            .receivingTelemetry(peripheralName: nil),
            .reconnecting(vin: "FENRTEST000000001", attempt: 1, maximumAttempts: 5)
        ]

        #expect(retryStates.allSatisfy { !mapper.showsProgress($0) })
        #expect(progressStates.allSatisfy { mapper.showsProgress($0) })
    }
}
