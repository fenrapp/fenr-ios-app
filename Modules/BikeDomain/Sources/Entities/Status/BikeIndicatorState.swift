public struct BikeIndicatorState: Equatable, Sendable {
    public let isHighBeamOn: Bool
    public let isRightBlinkerOn: Bool
    public let isLeftBlinkerOn: Bool
    public let isCheckEngineLightOn: Bool

    public init(
        isHighBeamOn: Bool = false,
        isRightBlinkerOn: Bool = false,
        isLeftBlinkerOn: Bool = false,
        isCheckEngineLightOn: Bool = false
    ) {
        self.isHighBeamOn = isHighBeamOn
        self.isRightBlinkerOn = isRightBlinkerOn
        self.isLeftBlinkerOn = isLeftBlinkerOn
        self.isCheckEngineLightOn = isCheckEngineLightOn
    }
}
