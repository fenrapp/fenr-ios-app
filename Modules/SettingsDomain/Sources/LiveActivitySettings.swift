public struct LiveActivitySettings: Codable, Equatable, Sendable {
    public enum DetailLevel: String, Codable, CaseIterable, Sendable {
        case summary
        case detailed
    }

    public var isEnabled: Bool
    public var showsRiding: Bool
    public var showsCharging: Bool
    public var ridingDetailLevel: DetailLevel
    public var chargingDetailLevel: DetailLevel

    public init(
        isEnabled: Bool = true,
        showsRiding: Bool = true,
        showsCharging: Bool = true,
        ridingDetailLevel: DetailLevel = .detailed,
        chargingDetailLevel: DetailLevel = .detailed
    ) {
        self.isEnabled = isEnabled
        self.showsRiding = showsRiding
        self.showsCharging = showsCharging
        self.ridingDetailLevel = ridingDetailLevel
        self.chargingDetailLevel = chargingDetailLevel
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, showsRiding, showsCharging, ridingDetailLevel, chargingDetailLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        showsRiding = try container.decodeIfPresent(Bool.self, forKey: .showsRiding) ?? true
        showsCharging = try container.decodeIfPresent(Bool.self, forKey: .showsCharging) ?? true
        ridingDetailLevel = try container.decodeIfPresent(DetailLevel.self, forKey: .ridingDetailLevel) ?? .detailed
        chargingDetailLevel = try container.decodeIfPresent(DetailLevel.self, forKey: .chargingDetailLevel) ?? .detailed
    }
}
