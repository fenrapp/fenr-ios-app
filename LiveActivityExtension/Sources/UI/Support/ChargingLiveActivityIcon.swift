enum ChargingLiveActivityIcon {
    static func name(for phase: ChargingLiveActivityPhase) -> String {
        switch phase {
        case .charging:
            "bolt.fill"
        case .balancing:
            "scale.3d"
        case .complete:
            "checkmark.circle.fill"
        case .stale:
            "clock.fill"
        case .connectionLost:
            "exclamationmark.triangle.fill"
        }
    }
}
