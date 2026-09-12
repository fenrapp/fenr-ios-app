import BikeDomain

actor BatteryHealthEmissionRecorder {
    private(set) var count = 0

    func append(_: BikeBatteryHealth) {
        count += 1
    }
}
