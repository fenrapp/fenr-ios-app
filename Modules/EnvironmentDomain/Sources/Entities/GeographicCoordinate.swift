public struct GeographicCoordinate: Equatable, Sendable {
    public let latitudeDegrees: Double
    public let longitudeDegrees: Double

    public init?(latitudeDegrees: Double, longitudeDegrees: Double) {
        guard latitudeDegrees.isFinite,
              longitudeDegrees.isFinite,
              (-90 ... 90).contains(latitudeDegrees),
              (-180 ... 180).contains(longitudeDegrees) else { return nil }
        self.latitudeDegrees = latitudeDegrees
        self.longitudeDegrees = longitudeDegrees
    }
}
