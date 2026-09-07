import ChargeControl

@MainActor
final class ChargeControlStateRecorder {
    private(set) var isFinished = false
    private(set) var states: [ChargeControlState] = []

    func finish() {
        isFinished = true
    }

    func record(_ state: ChargeControlState) {
        states.append(state)
    }
}
