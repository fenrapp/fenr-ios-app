import Foundation
import OSLog
import WatchCompanionData
import WatchCompanionDomain
import WatchConnectivity
import WatchDashboard

@MainActor
enum WatchAppFactory {
    static func makeViewModel() -> WatchDashboardViewModel {
        let session = WatchConnectivityCompanionSession(
            session: .default,
            codec: CompanionSnapshotCodec(encoder: JSONEncoder(), decoder: JSONDecoder()),
            store: CompanionSnapshotStore(defaults: .standard, key: "companion.watch.snapshot"),
            logger: Logger(subsystem: "in.fenr.app.watch", category: "Companion"),
            now: Date.init,
            transferGate: CompanionTransferGate(timeout: 15)
        )
        session.activate()
        return makeViewModel(session: session)
    }

    static func makeViewModel(session: any CompanionSession) -> WatchDashboardViewModel {
        WatchDashboardViewModel(
            observe: ObserveCompanionStateUseCase(session: session),
            mapper: WatchDashboardViewStateMapper(freshnessInterval: 15),
            now: Date.init
        )
    }
}
