public struct MapSourceDescriptor: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    public static let appleStandard = Self(
        id: "apple.standard",
        title: String(localized: .rideNavigationMapStyleStandard)
    )
    public static let appleHybrid = Self(
        id: "apple.hybrid",
        title: String(localized: .rideNavigationMapStyleSatellite)
    )
}
