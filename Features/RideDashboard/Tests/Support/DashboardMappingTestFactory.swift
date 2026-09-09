import ChargeControl
import Foundation
@testable import RideDashboard
import SettingsDomain

@MainActor
enum DashboardMappingTestFactory {
    static func ride(
        recorder: DashboardMapperCallRecorder, session: RideDashboardVehicleSession
    ) -> RideDashboardViewModel {
        RideDashboardViewModel(
            mapper: RideDashboardMapper(
                makeMeasurementMapper: { system in
                    recorder.record("rideMapper")
                    return RideDashboardMapperFactory.makeMeasurementMapper(
                        measurementSystem: system, locale: Locale(identifier: "en_GB")
                    )
                },
                speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper(),
                progressBarMapper: DashboardProgressBarMapper(), connectionMapper: RideDashboardConnectionMapper(),
                temperatureMapper: DashboardTemperatureSummaryMapper(),
                compactSpeedVisibilityMapper: DashboardCompactSpeedVisibilityMapper()
            ),
            cardLayoutMapper: DashboardCardLayoutMapper(), vehicleSession: session,
            timing: .live, continuityPolicy: RideDashboardContinuityPolicy(),
            initialConnectionStabilityPeriod: .zero, reconnectionNoticeDelay: .seconds(5),
            onContinuityChanged: { _ in }
        )
    }

    static func charging(
        recorder: DashboardMapperCallRecorder, session: ChargingDashboardVehicleSession,
        locale: Locale = Locale(identifier: "en_GB")
    ) -> ChargingMappingTestFixture {
        let repository = DashboardMappingChargeRepository()
        let control = ChargeControlSession(
            useCases: .init(
                prepare: .init(repository: repository), setPowerLimit: .init(repository: repository),
                setTarget: .init(repository: repository)
            ),
            logger: ChargeControlLogStore(isRecording: { false }),
            stateUpdater: ChargeControlStateUpdater(normalizer: ChargeControlNormalizer()),
            taskScheduler: ChargeControlTaskScheduler(debounceDelay: .zero, confirmationDelay: .seconds(30)),
            stateEmitter: ChargeControlStateEmitter()
        )
        let makeMapper: @Sendable (AppSettings, String?) -> ChargingDashboardMapper = { settings, vin in
            recorder.record("chargingMapper")
            return RideDashboardMapperFactory.makeChargingMapper(
                settings: settings, locale: locale, vin: vin
            )
        }
        return ChargingMappingTestFixture(
            model: ChargingDashboardViewModel(
                vehicleSession: session, chargeControl: control,
                mapper: RideDashboardMapperFactory.makeChargingMapper(
                    settings: .init(), locale: locale
                ),
                makeMapper: makeMapper
            ),
            control: control, repository: repository
        )
    }
}

struct ChargingMappingTestFixture {
    let model: ChargingDashboardViewModel
    let control: ChargeControlSession
    let repository: DashboardMappingChargeRepository
}
