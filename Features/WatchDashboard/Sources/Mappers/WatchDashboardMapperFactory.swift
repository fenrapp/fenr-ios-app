import Foundation
import MeasurementPresentation
import SettingsDomain

public enum WatchDashboardMapperFactory {
    public static func make(
        locale: Locale,
        now: @escaping @Sendable () -> Date,
        telemetryFreshnessInterval: TimeInterval
    ) -> WatchDashboardViewStateMapper {
        WatchDashboardViewStateMapper(
            makeMeasurementMapper: { measurementSystem in
                VehicleMeasurementMapper(
                    measurementSystem: measurementSystem.resolved(for: locale)
                )
            },
            measurementTextFormatter: VehicleMeasurementTextFormatter(locale: locale),
            timeRemainingFormatStyle: Duration.UnitsFormatStyle(
                allowedUnits: [.hours, .minutes],
                width: .narrow,
                maximumUnitCount: 2,
                zeroValueUnits: .hide,
                fractionalPart: .hide(rounded: .towardZero)
            ).locale(locale),
            now: now,
            telemetryFreshnessInterval: telemetryFreshnessInterval
        )
    }
}
