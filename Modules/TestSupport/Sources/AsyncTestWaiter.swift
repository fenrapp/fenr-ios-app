/// Waits for asynchronous test work to settle within a bounded interval.
@MainActor
public func waitUntil(
    timeout: Duration = .seconds(1),
    pollingInterval: Duration = .milliseconds(10),
    _ condition: @escaping @MainActor @Sendable () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout

    while clock.now < deadline {
        if await condition() {
            return true
        }

        try? await Task.sleep(for: pollingInterval)
    }

    return await condition()
}
