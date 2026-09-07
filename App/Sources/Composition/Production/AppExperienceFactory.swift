import CoreLocation
import EnvironmentData
import Foundation
import MaintenanceLog
import UserNotifications

@MainActor
enum AppExperienceFactory {
    static func makeController() -> AppExperienceController {
        let center = UNUserNotificationCenter.current()
        let scheduler = SystemMaintenanceReminderScheduler(center: center, calendar: .autoupdatingCurrent)
        let fileManager = FileManager()
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let demoFactory = DemoExperienceFactory(
            fileManager: fileManager, baseDirectory: support.appendingPathComponent("Demo", isDirectory: true),
            notifications: SystemDemoNotifications(center: center, calendar: .autoupdatingCurrent),
            makeDeviceSpeedRepository: {
                CoreLocationDeviceSpeedRepository(
                    locationManager: CLLocationManager(), requestsAuthorizationOnObservation: false
                )
            },
            makeCredentialStore: { KeychainBikeLockCredentialStore(service: $0) }
        )
        return AppExperienceController(
            selectionStore: DemoSelectionStore(
                defaults: .standard, encoder: JSONEncoder(), decoder: JSONDecoder(), makeID: UUID.init,
                makeDigits: { (0 ..< 9).map { _ in String(Int.random(in: 0 ... 9)) }.joined() }, now: Date.init
            ),
            makeReal: {
                let root = try ProductionAppDependencyContainerFactory.makeDefault(
                    maintenanceReminderScheduler: scheduler
                ).makeRootDependencies()
                return AppExperience(
                    id: UUID(), root: root, demoViewModel: nil,
                    close: { await root.shutDown() }, discard: {}
                )
            },
            makeDemo: { try await demoFactory.make(identity: $0) },
            discardDemo: { try await demoFactory.discard(identity: $0) }
        )
    }
}
