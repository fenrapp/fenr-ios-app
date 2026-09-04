public struct NavigationMapScene: Equatable, Sendable {
    public let source: MapSourceDescriptor
    public let displayStyle: NavigationMapDisplayStyle
    public let camera: NavigationMapCamera
    public let userCoordinate: NavigationMapCoordinate?
    public let userHeadingDegrees: Double?
    public let polylines: [NavigationMapPolyline]
    public let markers: [NavigationMapMarker]
    public let directionalIndicators: [NavigationMapDirectionalIndicator]
    public let showsCompassRing: Bool
    public let showsRoadsInFocus: Bool

    public init(
        source: MapSourceDescriptor = .appleStandard,
        displayStyle: NavigationMapDisplayStyle = .map,
        camera: NavigationMapCamera = .automatic,
        userCoordinate: NavigationMapCoordinate? = nil,
        userHeadingDegrees: Double? = nil,
        polylines: [NavigationMapPolyline] = [],
        markers: [NavigationMapMarker] = [],
        directionalIndicators: [NavigationMapDirectionalIndicator] = [],
        showsCompassRing: Bool = false,
        showsRoadsInFocus: Bool = false
    ) {
        self.source = source
        self.displayStyle = displayStyle
        self.camera = camera
        self.userCoordinate = userCoordinate
        self.userHeadingDegrees = userHeadingDegrees
        self.polylines = polylines
        self.markers = markers
        self.directionalIndicators = directionalIndicators
        self.showsCompassRing = showsCompassRing
        self.showsRoadsInFocus = showsRoadsInFocus
    }
}
