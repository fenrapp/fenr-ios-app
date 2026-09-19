public struct OfflineMapSelectionScene: Equatable {
    public let outlines: [[NavigationMapCoordinate]]
    public let existing: [[NavigationMapCoordinate]]
    public let center: NavigationMapCoordinate?
    public let isCorridor: Bool
    public let cameraCommand: Int

    public init(
        outlines: [[NavigationMapCoordinate]], existing: [[NavigationMapCoordinate]],
        center: NavigationMapCoordinate?, isCorridor: Bool, cameraCommand: Int = 0
    ) {
        self.outlines = outlines
        self.existing = existing
        self.center = center
        self.isCorridor = isCorridor
        self.cameraCommand = cameraCommand
    }
}
