import Foundation

@MainActor
final class BikeBLEConnectionWatchdog {
    typealias TimeoutHandler = @MainActor @Sendable (UUID) async -> Void

    private let timeoutScheduler: any BikeBLETimeoutScheduling
    private var activePeripheralIdentifier: UUID?

    init(timeoutScheduler: any BikeBLETimeoutScheduling) {
        self.timeoutScheduler = timeoutScheduler
    }

    func start(
        peripheralIdentifier: UUID,
        onTimeout: @escaping TimeoutHandler
    ) {
        activePeripheralIdentifier = peripheralIdentifier
        timeoutScheduler.schedule { [weak self] in
            guard let self,
                  activePeripheralIdentifier == peripheralIdentifier else { return }
            activePeripheralIdentifier = nil
            await onTimeout(peripheralIdentifier)
        }
    }

    func cancel() {
        activePeripheralIdentifier = nil
        timeoutScheduler.cancel()
    }
}
