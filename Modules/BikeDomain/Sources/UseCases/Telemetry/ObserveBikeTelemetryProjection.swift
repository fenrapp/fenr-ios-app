func observeBikeTelemetryProjection<Value: Equatable & Sendable>(
    repository: BikeRepository,
    transform: @escaping @Sendable (BikeTelemetry) -> Value
) async -> AsyncStream<Value> {
    let upstream = await repository.observeTelemetry()
    return AsyncStream { continuation in
        let task = Task {
            var previous: Value?
            for await telemetry in upstream {
                guard !Task.isCancelled else { break }
                let value = transform(telemetry)
                guard value != previous else { continue }
                previous = value
                continuation.yield(value)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
