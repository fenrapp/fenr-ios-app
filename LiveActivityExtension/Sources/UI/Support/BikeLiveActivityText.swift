import Foundation

enum BikeLiveActivityText {
    static var current: String { String(localized: .liveActivityCurrent) }
    static var mode: String { String(localized: .liveActivityMode) }
    static var power: String { String(localized: .liveActivityPower) }
    static var ready: String { String(localized: .liveActivityReady) }
    static let singleLineLimit = 1
    static var speed: String { String(localized: .liveActivitySpeed) }
    static var state: String { String(localized: .liveActivityState) }
    static var temperature: String { String(localized: .liveActivityTemperature) }

    static func remaining(_ text: String) -> String {
        String(localized: .liveActivityRemaining(duration: text))
    }

    static func target(_ percent: Int) -> String {
        String(localized: .liveActivityTarget(percent: percent))
    }

    static func status(_ state: BikeLiveActivityAttributes.ContentState) -> String {
        if state.phase == .complete {
            return ready
        }
        if let estimatedTimeRemaining = state.estimatedTimeRemaining {
            return remaining(estimatedTimeRemaining)
        }
        if state.mode == .riding {
            return runState(state.runState)
        }
        return phase(state.phase)
    }

    static func batteryAccessibilityLabel(_ percent: Int?) -> String {
        String(localized: .liveActivityAccessibilityBattery(
            batteryValue: BikeLiveActivityFormatter.batteryText(percent)
        ))
    }

    static func modeAccessibilityLabel(_ modeIndex: Int?) -> String {
        String(localized: .liveActivityAccessibilityMode(
            modeValue: BikeLiveActivityFormatter.modeText(modeIndex)
        ))
    }

    static func statusAccessibilityLabel(_ state: BikeLiveActivityAttributes.ContentState) -> String {
        String(localized: .liveActivityAccessibilityStatus(statusValue: status(state)))
    }

    static func minimalAccessibilityLabel(_ state: BikeLiveActivityAttributes.ContentState) -> String {
        var labels = [batteryAccessibilityLabel(state.batteryPercent)]
        if state.mode == .riding {
            labels.append(modeAccessibilityLabel(state.modeIndex))
        }
        labels.append(statusAccessibilityLabel(state))
        return labels.formatted(.list(type: .and))
    }

    static func metricAccessibilityLabel(title: String, value: String) -> String {
        String(localized: .liveActivityAccessibilityMetric(metricTitle: title, metricValue: value))
    }

    static func runState(_ state: BikeLiveActivityRunState) -> String {
        let resource: LocalizedStringResource = switch state {
        case .unknown: .liveActivityRunStateUnknown
        case .off: .liveActivityRunStateOff
        case .neutral: .liveActivityRunStateNeutral
        case .ride: .liveActivityRunStateRide
        case .charging: .liveActivityRunStateCharging
        case .crawlForward: .liveActivityRunStateCrawl
        case .crawlReverse: .liveActivityRunStateReverse
        }
        return String(localized: resource)
    }

    static func phase(_ phase: BikeLiveActivityPhase) -> String {
        let resource: LocalizedStringResource = switch phase {
        case .charging: .liveActivityPhaseCharging
        case .balancing: .liveActivityPhaseBalancing
        case .complete: .liveActivityPhaseChargeComplete
        case .riding: .liveActivityPhaseRiding
        case .neutral: .liveActivityPhaseNeutral
        case .crawl: .liveActivityPhaseCrawl
        case .fault: .liveActivityPhaseFault
        case .reconnecting: .liveActivityPhaseReconnecting
        case .stale: .liveActivityPhaseWaitingForUpdate
        case .connectionLost: .liveActivityPhaseConnectionLost
        }
        return String(localized: resource)
    }
}
