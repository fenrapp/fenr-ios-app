@testable import ChargeControl

@MainActor
enum ChargeControlSessionTestFactory {
    static func make(
        repository: ChargeControlRepository,
        debounceDelay: Duration = .seconds(1),
        confirmationDelay: Duration = .seconds(5)
    ) -> ChargeControlSession {
        ChargeControlSession(
            useCases: .init(
                prepare: .init(repository: repository),
                setPowerLimit: .init(repository: repository),
                setTarget: .init(repository: repository)
            ),
            logger: ChargeControlLogStore(isRecording: { true }),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler(
                debounceDelay: debounceDelay,
                confirmationDelay: confirmationDelay
            )
        )
    }
}
