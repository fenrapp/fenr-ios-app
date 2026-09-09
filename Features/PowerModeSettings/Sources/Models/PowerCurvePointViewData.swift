public struct PowerCurvePointViewData: Identifiable, Equatable, Sendable {
    public let id: Int
    public let rpm: Double
    public let rpmText: String
    public let value: Double
    public let maximum: Double
}
