import BikeEmulator
import BLETraceDomain

struct EmulatorDiagnosticsFixture {
    let repository: BikeEmulatorRepository
    let recorder: EmulatorTraceRecorder
    let captureState: BLETraceCaptureState
}

func makeEmulatorDiagnosticsFixture(
    startsSuccessfully: Bool = true,
    finishesSuccessfully: Bool = true
) -> EmulatorDiagnosticsFixture {
    let recorder = EmulatorTraceRecorder(
        startsSuccessfully: startsSuccessfully, finishesSuccessfully: finishesSuccessfully
    )
    let captureState = BLETraceCaptureState()
    let repository = BikeEmulatorRepositoryFactory.make(
        scenario: .parked,
        diagnostics: BikeEmulatorDiagnostics(
            recorder: recorder, captureState: captureState, uptimeNanoseconds: { 1_000_000 }
        )
    )
    return EmulatorDiagnosticsFixture(repository: repository, recorder: recorder, captureState: captureState)
}
