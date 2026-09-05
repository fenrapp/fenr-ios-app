import Foundation
import RideSession
import SettingsDomain

public struct DashboardAltitudeMapper: Sendable {
    private let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    public func map(_ snapshot: RideSessionSnapshot) -> DashboardAltitudeViewData {
        let usesFeet = snapshot.measurementSystem.resolved(for: locale) == .us
        let unit: UnitLength = usesFeet ? .feet : .meters
        let current = converted(snapshot.motion.altitudeMeters, to: unit)
        return .init(
            valueText: text(current),
            unitText: rideDashboardLocalized(
                usesFeet ? .rideDashboardAltitudeUnitFeet : .rideDashboardAltitudeUnitMeters
            ),
            minimumText: text(converted(snapshot.trip?.minimumAltitudeMeters, to: unit)),
            maximumText: text(converted(snapshot.trip?.maximumAltitudeMeters, to: unit)),
            ticks: current.map(ticks) ?? [],
            isAvailable: current != nil
        )
    }

    private func converted(_ meters: Double?, to unit: UnitLength) -> Double? {
        guard let meters, meters.isFinite else { return nil }
        let value = Measurement(value: meters, unit: UnitLength.meters).converted(to: unit).value
        return value.isFinite ? value : nil
    }

    private func text(_ value: Double?) -> String {
        value?.formatted(.number.locale(locale).precision(.fractionLength(0))) ?? "\u{2014}"
    }

    private func ticks(_ current: Double) -> [DashboardAltitudeViewData.Tick] {
        let centerTick = (current / Constants.minorInterval).rounded(.down)
        return (-Constants.halfTickCount...Constants.halfTickCount).map { offset in
            let index = centerTick + Double(offset)
            let value = index * Constants.minorInterval
            return .init(
                id: value,
                label: index.truncatingRemainder(dividingBy: Constants.majorTickFrequency) == .zero
                    ? text(value) : nil,
                position: Constants.centerPosition - (value - current) / Constants.visibleSpan
            )
        }
    }

    private enum Constants {
        static let minorInterval = 20.0
        static let majorTickFrequency = 5.0
        static let visibleSpan = 280.0
        static let centerPosition = 0.5
        static let halfTickCount = 8
    }
}
