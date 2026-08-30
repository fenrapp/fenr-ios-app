public struct GPXRouteImportLimits: Equatable, Sendable {
    public let maximumFileSizeBytes: Int
    public let maximumPointCount: Int

    public init(maximumFileSizeBytes: Int, maximumPointCount: Int) {
        precondition(maximumFileSizeBytes >= 0)
        precondition(maximumPointCount >= 0)
        self.maximumFileSizeBytes = maximumFileSizeBytes
        self.maximumPointCount = maximumPointCount
    }
}
