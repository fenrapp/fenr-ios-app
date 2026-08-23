@testable import BikeSDK
import Testing
import TestSupport

@MainActor
@Suite("BLE callback queue")
struct BikeBLECallbackQueueTests {
    @Test("A single worker preserves callback order and can restart")
    func preservesOrderAndRestarts() async {
        let queue = BikeBLECallbackQueue()
        let recorder = MainActorValueRecorder()
        queue.start()

        queue.enqueue { [recorder] in recorder.append(1) }
        queue.enqueue { [recorder] in recorder.append(2) }
        queue.enqueue { [recorder] in recorder.append(3) }
        #expect(await waitUntil { recorder.values.count == 3 })
        queue.cancelPending()
        queue.start()
        queue.enqueue { [recorder] in recorder.append(4) }
        #expect(await waitUntil { recorder.values.count == 4 })

        #expect(recorder.values == [1, 2, 3, 4])
    }

}
