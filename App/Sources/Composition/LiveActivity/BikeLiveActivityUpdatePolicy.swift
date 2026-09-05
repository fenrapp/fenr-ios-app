import Foundation
import RideDashboard
import SettingsDomain
import VehicleSession

struct BikeLiveActivityUpdatePolicy {
    let updateInterval: TimeInterval

    func allowsActivity(
        settings: LiveActivitySettings,
        state: BikeLiveActivityContentState,
        previousStableState: BikeLiveActivityContentState?
    ) -> Bool {
        guard settings.isEnabled else { return false }
        let mode = state.mode == .stale || state.mode == .connectionLost
            ? previousStableState?.mode ?? state.mode : state.mode
        let isCharging = mode == .charging || state.runState == .charging
        return isCharging ? settings.showsCharging : settings.showsRiding
    }

    func canStart(
        mapped: BikeLiveActivitySnapshot,
        source: VehicleSessionSnapshot,
        isSetupCompleted: Bool
    ) -> Bool {
        isSetupCompleted
            && source.isCanonicalTelemetryAvailable
            && mapped.hasRecentTelemetry
            && mapped.hasDisplayableTelemetry
            && mapped.isReceivingTelemetry
            && mapped.isLiveRunState
            && mapped.contentState.phase != .complete
            && mapped.contentState.mode != .stale
            && mapped.contentState.mode != .connectionLost
    }

    func shouldUpdate(
        state: BikeLiveActivityContentState,
        previous: BikeLiveActivityContentState?,
        previousUpdateDate: Date?,
        now: Date
    ) -> Bool {
        guard let previous, let previousUpdateDate else { return true }
        guard state != previous else { return false }
        if state.phase != previous.phase { return true }
        if state.showsDetails != previous.showsDetails { return true }
        if state.mode != previous.mode
            || state.runState != previous.runState
            || state.modeIndex != previous.modeIndex
            || state.isFaultActive != previous.isFaultActive
            || state.isConnectionLost != previous.isConnectionLost {
            return true
        }
        return now.timeIntervalSince(previousUpdateDate) >= updateInterval
    }

    func shouldEnd(mapped: BikeLiveActivitySnapshot, isSetupCompleted: Bool) -> Bool {
        let state = mapped.contentState
        if !isSetupCompleted || state.phase == .complete { return true }
        if !mapped.hasRecentTelemetry, state.mode != .connectionLost, state.mode != .stale {
            return true
        }
        return !mapped.isLiveRunState && !state.isFaultActive && state.mode != .connectionLost
    }
}
