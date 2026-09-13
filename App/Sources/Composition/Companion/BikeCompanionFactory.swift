import Foundation
import OSLog
import VehicleSession
import WatchCompanionData
import WatchConnectivity

@MainActor
enum BikeCompanionFactory {
    static func make(
        vehicleSession: any VehicleSessionService,
        isDemo: Bool
    ) -> BikeCompanionController? {
        guard !isDemo else { return nil }
        let companion = WatchConnectivityCompanionSession(
            session: .default,
            codec: CompanionSnapshotCodec(encoder: JSONEncoder(), decoder: JSONDecoder()),
            store: nil,
            logger: Logger(subsystem: "in.fenr.app", category: "WatchCompanion"),
            now: Date.init,
            transferGate: CompanionTransferGate(timeout: 15)
        )
        return BikeCompanionController(
            vehicleSession: vehicleSession,
            companion: companion,
            mapper: BikeCompanionSnapshotMapper(),
            now: Date.init,
            monitoringID: UUID()
        )
    }

}
