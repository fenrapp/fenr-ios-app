@testable import BikeSDK
import Foundation
import Testing

@Suite("BLE connection watchdog")
struct BikeBLEConnectionTimeoutTests {
    @MainActor
    @Test("A started watchdog reports its peripheral when the timeout fires")
    func startedWatchdogReportsTimedOutPeripheral() async {
        let timeoutScheduler = FakeBikeBLETimeoutScheduler()
        let watchdog = BikeBLEConnectionWatchdog(timeoutScheduler: timeoutScheduler)
        let expectedIdentifier = UUID()
        var timedOutIdentifier: UUID?

        watchdog.start(peripheralIdentifier: expectedIdentifier) { identifier in
            timedOutIdentifier = identifier
        }

        #expect(timeoutScheduler.hasPendingOperation)

        await timeoutScheduler.fire()

        #expect(timedOutIdentifier == expectedIdentifier)
        #expect(!timeoutScheduler.hasPendingOperation)
    }

    @MainActor
    @Test("Cancelling the watchdog suppresses a stale timeout")
    func cancelledWatchdogSuppressesTimeout() async {
        let timeoutScheduler = FakeBikeBLETimeoutScheduler()
        let watchdog = BikeBLEConnectionWatchdog(timeoutScheduler: timeoutScheduler)
        var didTimeOut = false

        watchdog.start(peripheralIdentifier: UUID()) { _ in
            didTimeOut = true
        }
        watchdog.cancel()

        await timeoutScheduler.fire()

        #expect(!didTimeOut)
        #expect(!timeoutScheduler.hasPendingOperation)
    }
}
