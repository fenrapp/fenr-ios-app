import BikeData
import BikeDomain
import Foundation
import RideNavigationDomain
import SettingsData
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Demo storage isolation")
struct DemoIsolationTests {
    @Test("Demo preferences and profile cannot replace the real context, even for the same synthetic VIN")
    func settingsAndProfileStaySeparate() async throws {
        let fixture = try DemoIsolationTestFixture()
        defer { try? fixture.cleanUp() }
        let experience = try await fixture.demo.factory.make(identity: fixture.demo.identity)
        let demoSettings = AppSettingsRepositoryFactory.make(
            userDefaults: try fixture.defaults(suite: fixture.demo.identity.suiteName),
            profileRepository: UserDefaultsBikeProfileRepository(
                userDefaults: try fixture.defaults(suite: fixture.demo.identity.suiteName)
            )
        )
        let realProfile = UserDefaultsBikeProfileRepository(
            userDefaults: try fixture.defaults(suite: fixture.realSuite)
        )
        let realSettings = AppSettingsRepositoryFactory.make(
            userDefaults: try fixture.defaults(suite: fixture.realSuite),
            profileRepository: realProfile
        )
        let profile = BikeProfile(vin: fixture.demo.identity.vin)
        await realProfile.saveProfile(profile)
        let settings = AppSettings(measurementSystem: .metric).scoped(toVIN: profile.vin)
        _ = try await realSettings.update(expectedVIN: profile.vin, change: .measurementSystem(.metric))
        let model = experience.root.featureStore.appSettingsViewModel
        _ = try await demoSettings.update(expectedVIN: profile.vin, change: .measurementSystem(.metric))
        model.start()
        #expect(await waitUntil { model.viewState.measurementSystem.selectedID == "metric" })
        model.selectMeasurementSystem(id: MeasurementSystem.imperial.rawValue)
        #expect(await waitUntil { await demoSettings.load().measurementSystem == .imperial })
        await experience.close()
        #expect(await realSettings.load() == settings)
        #expect(await realProfile.loadProfile() == profile)
        #expect(await demoSettings.load().measurementSystem == .imperial)
        let demoProfile = UserDefaultsBikeProfileRepository(
            userDefaults: try fixture.defaults(suite: fixture.demo.identity.suiteName)
        )
        #expect(await demoProfile.loadProfile()?.declaredPowerTier == .alpha)
        await realProfile.clearProfile()
        #expect(await demoProfile.loadProfile() != nil)
    }

    @Test("Trips, maintenance, calibration and routes stay in separate stores after demo closes")
    func persistentRecordsStaySeparate() async throws {
        let fixture = try DemoIsolationTestFixture()
        defer { try? fixture.cleanUp() }
        let experience = try await fixture.demo.factory.make(identity: fixture.demo.identity)
        let vin = fixture.demo.identity.vin
        let demoRides = try fixture.demo.makeRides()
        let demoMaintenance = try fixture.demo.makeMaintenance()
        let realRides = try fixture.realRides()
        let realMaintenance = try fixture.realMaintenance()
        #expect(await realRides.loadCompletedTrips(vin: vin).isEmpty)
        #expect(await realMaintenance.loadEntries(vin: vin).isEmpty)
        let trip = try #require(await demoRides.loadCompletedTrips(vin: vin).first)
        let entry = try #require(await demoMaintenance.loadEntries(vin: vin).first)
        #expect(await realRides.completeTrip(trip, at: trip.updatedAt))
        #expect(await realMaintenance.save(entry))
        #expect(await demoRides.deleteCompletedTrip(id: trip.id, vin: vin))
        #expect(await demoMaintenance.deleteEntry(id: entry.id, vin: vin))
        let demoDirectory = fixture.demo.directory.appendingPathComponent(fixture.demo.identity.id.uuidString)
        let demoCalibration = try fixture.calibration(directory: demoDirectory)
        let realCalibration = try fixture.calibration(directory: fixture.realDirectory)
        #expect(await demoCalibration.load(vin: vin) != nil)
        #expect(await realCalibration.load(vin: vin) == nil)
        let demoRoutes = fixture.routes(directory: demoDirectory)
        let realRoutes = fixture.routes(directory: fixture.realDirectory)
        let route = RideRoute(name: "Synthetic demo route", createdAt: Date(), segments: [])
        try await demoRoutes.save(route)
        try await demoRoutes.saveDraft(route)
        let demoLinks = try fixture.mapLinks(suite: fixture.demo.identity.suiteName)
        let realLinks = try fixture.mapLinks(suite: fixture.realSuite)
        let link = IncomingMapLink(url: try #require(URL(string: "https://maps.apple.com/?q=Demo")), receivedAt: Date())
        try await demoLinks.save(link)
        await experience.close()
        #expect(await realRides.loadCompletedTrips(vin: vin).map(\.id) == [trip.id])
        #expect(await realMaintenance.loadEntries(vin: vin).map(\.id) == [entry.id])
        #expect(await realRoutes.loadRoutes().isEmpty)
        #expect(await realRoutes.loadDraft() == nil)
        #expect(try await realLinks.consume() == nil)
        #expect(try await demoLinks.consume() == link)
        #expect(await demoRoutes.loadRoutes().map(\.id) == [route.id])
        #expect(await demoRoutes.loadDraft()?.id == route.id)
    }

    @Test("Demo composition requests only its isolated credential service")
    func credentialsUseDemoService() async throws {
        let recorder = DemoCredentialServiceRecorder()
        let fixture = DemoExperienceTestFixture(makeCredentialStore: recorder.makeStore)
        let experience = try await fixture.factory.make(identity: fixture.identity)
        #expect(recorder.requestedServices == [fixture.identity.credentialService])
        #expect(!recorder.requestedServices.contains("com.fenr.app.bike-lock"))
        await experience.close()
        #expect(recorder.requestedServices == [fixture.identity.credentialService])
        try await experience.discard()
    }
}
