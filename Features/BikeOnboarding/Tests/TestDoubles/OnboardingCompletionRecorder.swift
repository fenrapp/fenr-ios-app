@MainActor
final class OnboardingCompletionRecorder {
    private var vin: String?
    private var records = 0

    func record(_ vin: String) {
        self.vin = vin
        records += 1
    }
    func value() -> String? { vin }
    func count() -> Int { records }
}
