public struct NavigationMapLineAppearance: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let lineWidth: Double

    public init(red: Double, green: Double, blue: Double, lineWidth: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.lineWidth = lineWidth
    }
}
