import Foundation
import MeasurementPresentation
import SettingsDomain

public struct RideHistoryMeasurementMapperFactory: Sendable {
    public init() {}

    func make(
        measurementSystem: MeasurementSystem,
        locale: Locale
    ) -> VehicleMeasurementMapper {
        VehicleMeasurementMapper(measurementSystem: measurementSystem.resolved(for: locale))
    }
}
