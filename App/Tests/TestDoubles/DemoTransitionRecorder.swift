import Foundation

@MainActor
final class DemoTransitionRecorder {
    private(set) var events: [String] = []
    private var continuation: CheckedContinuation<Void, Never>?
    var isWaiting: Bool { continuation != nil }

    func record(_ event: String) { events.append(event) }

    func wait(event: String = "build-demo") async {
        events.append(event)
        await withCheckedContinuation { continuation = $0 }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
