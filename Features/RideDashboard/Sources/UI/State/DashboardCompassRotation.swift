enum DashboardCompassRotation {
    static func nearestEquivalent(to targetDegrees: Double, from currentDegrees: Double) -> Double {
        let target = targetDegrees.normalizedCompassDegrees
        let current = currentDegrees.normalizedCompassDegrees
        var delta = target - current
        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }
        return currentDegrees + delta
    }
}

private extension Double {
    var normalizedCompassDegrees: Double {
        let value = truncatingRemainder(dividingBy: 360)
        return value >= .zero ? value : value + 360
    }
}
