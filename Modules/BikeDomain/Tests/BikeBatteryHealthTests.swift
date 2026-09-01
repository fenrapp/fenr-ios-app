import BikeDomain
import Testing

@Suite("Bike battery health")
struct BikeBatteryHealthTests {
    @Test("Vehicle and BMS faults remain independent")
    func faultSourcesAreIndependent() {
        let healthy = BikeBatteryHealth()
        let vehicleFault = BikeBatteryHealth(isVehicleFaultActive: true)
        let positiveBMSFault = BikeBatteryHealth(positiveBMSFaultBits: 1)
        let negativeBMSFault = BikeBatteryHealth(negativeBMSFaultBits: 1)

        #expect(!healthy.isVehicleFaultActive)
        #expect(!healthy.isBMSFaultActive)
        #expect(!healthy.isFaultActive)
        #expect(vehicleFault.isVehicleFaultActive)
        #expect(!vehicleFault.isBMSFaultActive)
        #expect(vehicleFault.isFaultActive)
        #expect(!positiveBMSFault.isVehicleFaultActive)
        #expect(positiveBMSFault.isBMSFaultActive)
        #expect(positiveBMSFault.isFaultActive)
        #expect(!negativeBMSFault.isVehicleFaultActive)
        #expect(negativeBMSFault.isBMSFaultActive)
        #expect(negativeBMSFault.isFaultActive)
    }
}
