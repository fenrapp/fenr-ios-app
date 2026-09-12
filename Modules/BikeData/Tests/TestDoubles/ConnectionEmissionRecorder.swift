import BikeDomain

actor ConnectionEmissionRecorder {
    private(set) var count = 0

    func append(_: BikeConnection) {
        count += 1
    }
}
