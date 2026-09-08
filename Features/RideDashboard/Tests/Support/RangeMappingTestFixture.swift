import Foundation
@testable import RideDashboard
import RideSessionDomain

@MainActor
struct RangeMappingTestFixture {
    let repository: CurrentTripCardTripRepository
    let session: TestRideSessionService
    let model: RangeCardViewModel

    init() {
        repository = CurrentTripCardTripRepository(completedTrips: [DashboardHistoryCardData.trip()])
        session = TestRideSessionService(snapshot: RangeMappingFixtures.snapshot(trip: nil))
        model = RangeCardViewModel(
            useCases: .init(loadHistory: .init(repository: repository)),
            mapper: .init(locale: Locale(identifier: "en_GB"), estimator: RideRangeEstimator()),
            session: session
        )
    }
}
