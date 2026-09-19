public struct RideNavigationMapModeState: Equatable, Sendable {
    public let selectedID: String
    public let title: String
    public let detail: String
    public let isEmphasized: Bool
    public let symbol: String
    public let choices: [MapSourceDescriptor]

    public static let normal = Self(
        selectedID: "map.normal", title: String(localized: .rideNavigationNormalMode),
        detail: String(localized: .rideNavigationNormalModeDetail), isEmphasized: false, symbol: "map.fill",
        choices: [
            .init(id: "map.normal", title: String(localized: .rideNavigationNormalMode)),
            .init(id: "map.offline", title: String(localized: .rideNavigationOfflineMode))
        ]
    )
}
