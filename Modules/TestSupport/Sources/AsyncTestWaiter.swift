/// Waits for asynchronous test work to settle within a bounded interval.
///
/// The condition should cooperate with task cancellation and return promptly. Cancellation, a
/// sleep failure, or reaching the timeout before a successful evaluation returns `false`.
@MainActor
public func waitUntil(
    timeout: Duration = .seconds(1),
    pollingInterval: Duration = .milliseconds(10),
    _ condition: @escaping @MainActor @Sendable () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    return await waitUntil(
        timeout: timeout,
        pollingInterval: pollingInterval,
        clock: clock,
        sleepUntil: { deadline in
            try await clock.sleep(until: deadline)
        },
        condition: condition
    )
}

@MainActor
func waitUntil<ClockType: Clock>(
    timeout: Duration,
    pollingInterval: Duration,
    clock: ClockType,
    sleepUntil: @escaping @Sendable (ClockType.Instant) async throws -> Void,
    condition: @escaping @MainActor @Sendable () async -> Bool
) async -> Bool where ClockType.Duration == Duration {
    guard !Task.isCancelled else { return false }

    guard timeout > .zero, pollingInterval > .zero else {
        let result = await condition()
        return !Task.isCancelled && result
    }

    let deadline = clock.now.advanced(by: timeout)

    while !Task.isCancelled {
        if await condition() {
            return !Task.isCancelled
        }

        guard !Task.isCancelled else { return false }

        let now = clock.now
        guard now < deadline else { return false }

        let nextPoll = now.advanced(by: pollingInterval)
        let wakeUp = min(nextPoll, deadline)

        do {
            try await sleepUntil(wakeUp)
        } catch {
            return false
        }

        guard !Task.isCancelled, clock.now < deadline else { return false }
    }

    return false
}
