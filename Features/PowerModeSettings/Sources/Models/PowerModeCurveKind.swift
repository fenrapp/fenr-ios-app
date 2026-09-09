public enum PowerModeCurveKind: String, CaseIterable, Identifiable, Sendable {
    case power
    case regeneration

    public var id: String { rawValue }
}
