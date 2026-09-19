public struct OfflineMapSelectionInsets: Equatable, Sendable {
    public let top: Double
    public let leading: Double
    public let bottom: Double
    public let trailing: Double

    public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}
