import BLETraceDomain

public struct ObserveBLETraceRecordingFailuresUseCase: Sendable {
    private let repository: any BLETraceLogRepository

    public init(repository: any BLETraceLogRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<BLETraceRecordingFailure?> {
        await repository.observeRecordingFailures()
    }
}
