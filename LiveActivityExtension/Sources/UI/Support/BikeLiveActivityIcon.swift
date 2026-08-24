enum BikeLiveActivityIcon {
    static func name(for phase: BikeLiveActivityPhase) -> String {
        switch phase {
        case .charging:
            "bolt.fill"
        case .balancing:
            "scale.3d"
        case .complete:
            "checkmark.circle.fill"
        case .riding:
            "gauge.with.dots.needle.67percent"
        case .neutral:
            "pause.circle.fill"
        case .crawl:
            "tortoise.fill"
        case .fault:
            "exclamationmark.triangle.fill"
        case .stale:
            "clock.fill"
        case .connectionLost:
            "exclamationmark.triangle.fill"
        }
    }
}
