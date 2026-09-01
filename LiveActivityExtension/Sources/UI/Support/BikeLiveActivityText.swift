enum BikeLiveActivityText {
    static let current = "Current"
    static let mode = "Mode"
    static let power = "Power"
    static let ready = "Ready"
    static let singleLineLimit = 1
    static let speed = "Speed"
    static let temperature = "Temp"

    static func remaining(_ text: String) -> String {
        "\(text) remaining"
    }

    static func target(_ percent: Int) -> String {
        "Target \(percent)%"
    }

    static func status(_ state: BikeLiveActivityAttributes.ContentState) -> String {
        if state.phase == .complete {
            return ready
        }
        if let estimatedTimeRemaining = state.estimatedTimeRemaining {
            return remaining(estimatedTimeRemaining)
        }
        if state.mode == .riding {
            return state.runState.displayTitle
        }
        return state.phase.displayTitle
    }

    static func batteryAccessibilityLabel(_ percent: Int?) -> String {
        "Battery \(BikeLiveActivityFormatter.batteryText(percent))"
    }

    static func modeAccessibilityLabel(_ modeIndex: Int?) -> String {
        "Mode \(BikeLiveActivityFormatter.modeText(modeIndex))"
    }

    static func statusAccessibilityLabel(_ state: BikeLiveActivityAttributes.ContentState) -> String {
        "Status \(status(state))"
    }

    static func minimalAccessibilityLabel(_ state: BikeLiveActivityAttributes.ContentState) -> String {
        var labels = [batteryAccessibilityLabel(state.batteryPercent)]
        if state.mode == .riding {
            labels.append(modeAccessibilityLabel(state.modeIndex))
        }
        labels.append(statusAccessibilityLabel(state))
        return labels.joined(separator: ", ")
    }
}
