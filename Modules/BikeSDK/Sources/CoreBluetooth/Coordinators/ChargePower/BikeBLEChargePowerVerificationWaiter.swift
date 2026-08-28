import Foundation

protocol BikeBLEChargePowerVerificationWaiting: Sendable {
    func wait() async throws
}

struct BikeBLEChargePowerVerificationWaiter: BikeBLEChargePowerVerificationWaiting {
    let delay: Duration

    init(delay: Duration = .milliseconds(150)) {
        self.delay = delay
    }

    func wait() async throws {
        try await Task.sleep(for: delay)
    }
}
