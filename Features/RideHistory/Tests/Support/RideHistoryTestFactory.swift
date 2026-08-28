import Foundation
@testable import RideHistory
import RideSession
import RideSessionDomain
import SettingsDomain

@MainActor
enum RideHistoryTestFactory {
    static func make(
        trips: [RideTrip],
        measurementSystem: MeasurementSystem = .metric
    ) -> Fixture {
        let repository = RideHistoryTestRepository(trips: trips)
        let session = RideHistoryTestSession(
            repository: repository,
            snapshot: snapshot(measurementSystem: measurementSystem)
        )
        let viewModel = RideHistoryViewModel(
            useCases: .init(
                loadHistory: .init(repository: repository),
                loadDetail: .init(repository: repository)
            ),
            session: session,
            mapper: RideHistoryMapper(locale: Locale(identifier: "en_US"))
        )
        return Fixture(viewModel: viewModel, repository: repository, session: session)
    }

    static func snapshot(
        vin: String = RideHistoryFixtures.vin,
        measurementSystem: MeasurementSystem = .metric,
        revision: Int = .zero
    ) -> RideSessionSnapshot {
        .init(
            vehicleIdentity: .vin(vin),
            measurementSystem: measurementSystem,
            historyRevision: revision
        )
    }

    struct Fixture {
        let viewModel: RideHistoryViewModel
        let repository: RideHistoryTestRepository
        let session: RideHistoryTestSession
    }
}
