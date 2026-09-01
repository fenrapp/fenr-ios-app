public struct NavigationMapCoordinate: Equatable, Hashable, Sendable {
    public let latitudeDegrees: Double
    public let longitudeDegrees: Double

    public init?(latitudeDegrees: Double, longitudeDegrees: Double) {
        guard latitudeDegrees.isFinite,
              longitudeDegrees.isFinite,
              (-90.0 ... 90.0).contains(latitudeDegrees),
              (-180.0 ... 180.0).contains(longitudeDegrees) else {
            return nil
        }
        self.latitudeDegrees = latitudeDegrees
        self.longitudeDegrees = longitudeDegrees
    }
}
