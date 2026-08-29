public struct RoadRoutePreferences: Equatable, Sendable {
    public let avoidsTolls: Bool
    public let avoidsHighways: Bool

    public init(avoidsTolls: Bool = false, avoidsHighways: Bool = false) {
        self.avoidsTolls = avoidsTolls
        self.avoidsHighways = avoidsHighways
    }
}
