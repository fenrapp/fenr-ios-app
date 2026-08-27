import Foundation
import MeasurementPresentation
import RideSessionDomain
import SettingsDomain

public enum RideDashboardMapperFactory {
    public static func makeMeasurementMapper(
        measurementSystem: MeasurementSystem,
        locale: Locale
    ) -> RideDashboardMeasurementMapper {
        RideDashboardMeasurementMapper(
            measurementMapper: VehicleMeasurementMapper(
                measurementSystem: measurementSystem.resolved(for: locale)
            ),
            textFormatter: VehicleMeasurementTextFormatter(locale: locale)
        )
    }

    public static func makeRideMapper(locale: Locale) -> RideDashboardMapper {
        RideDashboardMapper(
            makeMeasurementMapper: { measurementSystem in
                makeMeasurementMapper(
                    measurementSystem: measurementSystem,
                    locale: locale
                )
            },
            speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper(),
            progressBarMapper: DashboardProgressBarMapper()
        )
    }

    public static func makeCurrentTripMapper(locale: Locale) -> CurrentTripCardMapper {
        CurrentTripCardMapper(
            makeMeasurementMapper: { measurementSystem in
                makeMeasurementMapper(
                    measurementSystem: measurementSystem,
                    locale: locale
                )
            },
            durationFormatStyle: Duration.TimeFormatStyle(
                pattern: .hourMinuteSecond(
                    padHourToLength: 2,
                    fractionalSecondsLength: 0
                )
            ).locale(locale),
            speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper()
        )
    }

    public static func makeTripStatisticsMapper(locale: Locale) -> TripStatisticsCardMapper {
        TripStatisticsCardMapper(
            makeMeasurementMapper: { measurementSystem in
                makeMeasurementMapper(
                    measurementSystem: measurementSystem,
                    locale: locale
                )
            },
            durationFormatStyle: Duration.TimeFormatStyle(
                pattern: .hourMinute(
                    padHourToLength: 2,
                    roundSeconds: .towardZero
                )
            ).locale(locale)
        )
    }

    public static func makeEfficiencyMapper(locale: Locale) -> EfficiencyCardMapper {
        EfficiencyCardMapper(locale: locale)
    }

    public static func makeRangeMapper(locale: Locale) -> RangeCardMapper {
        RangeCardMapper(locale: locale, estimator: RideRangeEstimator())
    }

    public static func makeRideDynamicsMapper(locale: Locale) -> RideDynamicsCardMapper {
        RideDynamicsCardMapper(locale: locale)
    }

    public static func makeChargingMapper(
        settings: AppSettings,
        locale: Locale,
        vin: String? = nil
    ) -> ChargingDashboardMapper {
        ChargingDashboardMapper(
            measurementMapper: makeMeasurementMapper(
                measurementSystem: settings.measurementSystem,
                locale: locale
            ),
            timeRemainingFormatStyle: Duration.UnitsFormatStyle(
                allowedUnits: [.hours, .minutes],
                width: .narrow,
                maximumUnitCount: 2,
                zeroValueUnits: .hide,
                fractionalPart: .hide(rounded: .towardZero)
            ).locale(locale),
            batteryPackCapacity: settings.batteryPackCapacity(forVIN: vin),
            controlStatusMapper: ChargingDashboardControlStatusMapper()
        )
    }
}
