actor OnboardingCompletionRecorder {
    private var vin: String?

    func record(_ vin: String) { self.vin = vin }
    func value() -> String? { vin }
}
