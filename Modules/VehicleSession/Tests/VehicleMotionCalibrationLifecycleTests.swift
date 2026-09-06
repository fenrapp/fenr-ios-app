import Testing
import TestSupport
@testable import VehicleSession

@Suite("Vehicle motion calibration lifecycle")
struct VehicleMotionCalibrationLifecycleTests {
    @Test("Stop drains a cancelled calibration read before a clean restart")
    func drainsCalibrationReadBeforeRestart() async {
        let fixture = makeVehicleSessionFixture()
        await fixture.motionCalibration.suspendNextLoadIgnoringCancellation()
        await fixture.service.start()
        #expect(await waitUntil { await fixture.motionCalibration.hasPendingLoad() })

        let stopping = Task { await fixture.service.stop() }
        #expect(await waitUntil {
            let isStopping = await fixture.service.isStopping
            let isReadCancelled = await fixture.service.motionCalibrationTask?.isCancelled
            return isStopping && isReadCancelled == true
        })

        await fixture.motionCalibration.resumeLoad()
        await stopping.value
        #expect(await fixture.service.motionCalibrationTask == nil)
        #expect(await fixture.service.hasLoadedMotionCalibration == false)

        await fixture.service.start()
        #expect(await waitUntil { await fixture.service.hasLoadedMotionCalibration })
        await fixture.service.stop()
    }
}
