enum ChargeControlCommand: Equatable {
    case power(watts: Int)
    case target(percent: Int)

    var statusValue: String {
        switch self {
        case .power(let watts): "\(watts) W"
        case .target(let percent): "\(percent)%"
        }
    }

    func controlsSameSetting(as other: Self) -> Bool {
        switch (self, other) {
        case (.power, .power), (.target, .target): true
        default: false
        }
    }

    func matches(confirmedWatts: Int, confirmedTargetPercent: Int) -> Bool {
        switch self {
        case .power(let watts): confirmedWatts == watts
        case .target(let percent): confirmedTargetPercent == percent
        }
    }

    func isConfirmed(in state: ChargeControlState) -> Bool {
        switch self {
        case .power(let watts): state.confirmedWatts == watts
        case .target(let percent): state.confirmedTargetPercent == percent
        }
    }

    func mismatchDescription(in state: ChargeControlState) -> String {
        switch self {
        case .power(let watts):
            "5001.maximumPower=\(state.confirmedWatts.map(String.init) ?? "unknown") W, target=\(watts) W"
        case .target(let percent):
            "5001.maximumStateOfCharge="
                + "\(state.confirmedTargetPercent.map(String.init) ?? "unknown")%, target=\(percent)%"
        }
    }
}
