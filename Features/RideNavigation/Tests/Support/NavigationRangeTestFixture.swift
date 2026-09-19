import Foundation
@testable import RideNavigation
import RideSessionDomain
import TestSupport

@MainActor
struct NavigationRangeTestFixture {
    let session: NavigationRangeSession
    let repository: NavigationRangeRepository
    let model: RideNavigationRangeViewModel

    init() {
        session = NavigationRangeSession(
            events: TestEventHub(bufferingPolicy: .unbounded), snapshot: NavigationRangeFixtures.snapshot()
        )
        repository = NavigationRangeRepository(trips: [NavigationRangeFixtures.history()])
        model = RideNavigationRangeViewModel(
            session: session, loadHistory: .init(repository: repository),
            mapper: .init(estimator: RideRangeEstimator(), locale: Locale(identifier: "en_GB"))
        )
    }
}
