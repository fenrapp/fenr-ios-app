import Foundation
import WatchCompanionDomain

public struct WatchDashboardViewStateMapper: Sendable {
    private let freshnessInterval: TimeInterval

    public init(freshnessInterval: TimeInterval) {
        self.freshnessInterval = freshnessInterval
    }

    public func map(_ state: CompanionState, now: Date) -> WatchDashboardViewState {
        guard let snapshot = state.snapshot, let date = snapshot.telemetryAt else {
            return WatchDashboardViewState(status: String(localized: state.isReachable
                ? .watchCompanionConnectBike : .watchCompanionOpenPhone))
        }
        let fresh = now.timeIntervalSince(date) >= -freshnessInterval
            && now.timeIntervalSince(date) <= freshnessInterval
        let stale = !fresh || !snapshot.bikeConnected || !state.isReachable
        let status: LocalizedStringResource
        if !state.isReachable {
            status = .watchCompanionPhoneUnavailable
        } else if !snapshot.bikeConnected {
            status = .watchCompanionBikeDisconnected
        } else if !fresh {
            status = .watchCompanionWaitingUpdate
        } else {
            status = .watchCompanionLive
        }
        return WatchDashboardViewState(
            hasData: true,
            batteryEmphasis: batteryEmphasis(snapshot.batteryPercent),
            showsMap: snapshot.activity == .riding,
            isCharging: snapshot.isCharging,
            isStale: stale,
            status: String(localized: status),
            updatedAt: date,
            batteryPercent: snapshot.batteryPercent,
            map: operatingState(snapshot),
            traction: (snapshot.activity == .riding ? snapshot.tractionPercent : nil).map {
                ($0 / 100).formatted(.percent.precision(.fractionLength(0...1)))
            } ?? "--",
            chargingPower: snapshot.chargingPowerWatts.map {
                Measurement(value: $0 / 1_000, unit: UnitPower.kilowatts)
                    .formatted(.measurement(width: .abbreviated, usage: .asProvided))
            } ?? "--",
            chargingCurrent: snapshot.chargingCurrentAmperes.map {
                Measurement(value: $0, unit: UnitElectricCurrent.amperes)
                    .formatted(.measurement(width: .abbreviated, usage: .asProvided))
            } ?? "--",
            chargeETA: snapshot.chargeRemainingSeconds.map {
                Duration.seconds($0).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
            }
        )
    }

    private func operatingState(_ snapshot: CompanionSnapshot) -> String {
        switch snapshot.activity {
        case .off: String(localized: .watchCompanionOff)
        case .neutral: String(localized: .watchCompanionNeutral)
        case .crawl: String(localized: .watchCompanionCrawl)
        case .charging: String(localized: .watchDashboardCharging)
        case .riding: snapshot.mapName ?? snapshot.mapIndex.map(String.init) ?? "--"
        case .unknown, nil: "--"
        }
    }

    private func batteryEmphasis(_ percent: Int?) -> WatchDashboardViewState.BatteryEmphasis {
        guard let percent else { return .unavailable }
        switch percent {
        case ...20: return .critical
        case ...50: return .warning
        default: return .positive
        }
    }

}
