import Foundation
import MeasurementPresentation
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
        RideDashboardMapper { measurementSystem in
            makeMeasurementMapper(
                measurementSystem: measurementSystem,
                locale: locale
            )
        }
    }

    public static func makeChargingMapper(
        settings: AppSettings,
        locale: Locale
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
            batteryPackCapacity: settings.batteryPackCapacity,
            controlStatusMapper: ChargingDashboardControlStatusMapper()
        )
    }
}
