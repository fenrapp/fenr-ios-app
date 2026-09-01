import Foundation
import RideHistory
import RideSession
import RideSessionDomain

@MainActor
struct RideHistoryDependencyContainer {
    func makeViewModel(
        repository: any RideTripRepository,
        session: any RideSessionService
    ) -> RideHistoryViewModel {
        let locale = Locale.autoupdatingCurrent
        return RideHistoryViewModel(
            useCases: .init(
                loadHistory: .init(repository: repository),
                loadDetail: .init(repository: repository)
            ),
            session: session,
            mapper: RideHistoryMapper(
                locale: locale,
                measurementMapperFactory: RideHistoryMeasurementMapperFactory()
            )
        )
    }
}
