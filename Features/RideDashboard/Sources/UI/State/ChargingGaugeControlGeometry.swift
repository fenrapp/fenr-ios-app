import CoreGraphics

enum ChargingGaugeArcGeometry {
    static let horizontalInset: CGFloat = 32
    static let controlBottomInset: CGFloat = 10
    static let targetRadiusOffset: CGFloat = 18
    static let powerRadiusOffset: CGFloat = -18
}

enum ChargingGaugeControl: Equatable {
    case target
    case power
}

enum ChargingGaugeControlIntent: Equatable {
    case target(percent: Double)
    case power(watts: Double)
}

struct ChargingGaugeInteractionState: Equatable {
    private(set) var activeControl: ChargingGaugeControl?
    private(set) var displayedPowerWatts: Double
    private(set) var displayedTargetPercent: Double
    private var initialValue: Double?

    init(displayedPowerWatts: Double, displayedTargetPercent: Double) {
        self.displayedPowerWatts = displayedPowerWatts
        self.displayedTargetPercent = displayedTargetPercent
    }

    mutating func update(
        startLocation: CGPoint,
        location: CGPoint,
        geometry: ChargingGaugeControlGeometry,
        controlState: ChargingDashboardControlViewState
    ) {
        if activeControl == nil {
            activeControl = geometry.nearestControl(to: startLocation)
            initialValue = switch activeControl {
            case .target: displayedTargetPercent
            case .power: displayedPowerWatts
            case nil: nil
            }
        }
        switch activeControl {
        case .target:
            displayedTargetPercent = geometry.value(
                at: location,
                minimum: controlState.target.minimum,
                maximum: controlState.target.maximum,
                step: controlState.target.step
            )
        case .power:
            displayedPowerWatts = geometry.value(
                at: location,
                minimum: controlState.power.minimum,
                maximum: controlState.power.maximum,
                step: controlState.power.step
            )
        case nil:
            break
        }
    }

    mutating func finish() -> ChargingGaugeControlIntent? {
        defer {
            activeControl = nil
            initialValue = nil
        }
        switch activeControl {
        case .target where displayedTargetPercent != initialValue:
            return .target(percent: displayedTargetPercent)
        case .power where displayedPowerWatts != initialValue:
            return .power(watts: displayedPowerWatts)
        case .target, .power, nil:
            return nil
        }
    }

    mutating func synchronizePower(_ watts: Double) {
        guard activeControl != .power else { return }
        displayedPowerWatts = watts
    }

    mutating func synchronizeTarget(_ percent: Double) {
        guard activeControl != .target else { return }
        displayedTargetPercent = percent
    }

    mutating func adjustPower(_ watts: Double) {
        displayedPowerWatts = watts
    }

    mutating func adjustTarget(_ percent: Double) {
        displayedTargetPercent = percent
    }
}

struct ChargingGaugeControlGeometry {
    let size: CGSize

    var center: CGPoint {
        CGPoint(
            x: size.width / 2,
            y: max(.zero, size.height - ChargingGaugeArcGeometry.controlBottomInset)
        )
    }

    var gaugeRadius: CGFloat {
        max(
            .zero,
            min(
                (size.width / 2) - ChargingGaugeArcGeometry.horizontalInset,
                center.y - ChargingGaugeArcGeometry.horizontalInset
            )
        )
    }

    func nearestControl(to location: CGPoint) -> ChargingGaugeControl? {
        guard location.y <= center.y else { return nil }
        let distance = hypot(location.x - center.x, location.y - center.y)
        let targetDistance = abs(distance - (gaugeRadius + ChargingGaugeArcGeometry.targetRadiusOffset))
        let powerDistance = abs(distance - (gaugeRadius + ChargingGaugeArcGeometry.powerRadiusOffset))
        let nearest = min(targetDistance, powerDistance)
        guard nearest <= Constants.maximumHitDistance else { return nil }
        return targetDistance <= powerDistance ? .target : .power
    }

    func progress(at location: CGPoint) -> Double {
        if location.y > center.y {
            return location.x < center.x ? .zero : 1
        }
        let radians = atan2(location.y - center.y, location.x - center.x)
        let degrees = radians * 180 / .pi
        let upperArcDegrees = degrees <= .zero ? degrees + 360 : degrees
        return min(max((upperArcDegrees - 180) / 180, .zero), 1)
    }

    func value(
        at location: CGPoint,
        minimum: Double,
        maximum: Double,
        step: Double
    ) -> Double {
        let rawValue = minimum + progress(at: location) * (maximum - minimum)
        let stepped = ((rawValue - minimum) / step).rounded() * step + minimum
        return min(max(stepped, minimum), maximum)
    }

    static func normalizedProgress(value: Double, minimum: Double, maximum: Double) -> Double {
        guard maximum > minimum else { return .zero }
        return min(max((value - minimum) / (maximum - minimum), .zero), 1)
    }

    enum Constants {
        static let maximumHitDistance: CGFloat = 24
    }
}
