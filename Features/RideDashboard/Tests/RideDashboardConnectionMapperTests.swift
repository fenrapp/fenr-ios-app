import BikeDomain
@testable import RideDashboard
import Testing

@Suite("Ride dashboard connection mapper")
struct RideDashboardConnectionMapperTests {
    @Test("Connection failures do not expose transport details")
    func hidesConnectionFailureDetails() {
        let mapper = RideDashboardConnectionMapper()

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
}
