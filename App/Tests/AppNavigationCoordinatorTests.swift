import AppSettings
import BatteryHealth
import BikeDiagnostics
import DashboardCardSettings
import Foundation
import MaintenanceLog
import RideDashboard
import RideHistory
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
@Suite("App navigation coordinator")
struct AppNavigationCoordinatorTests {
    @Test("Builds canonical routes and ignores an identical top push")
    func canonicalRoutesAndDeduplication() {
        let coordinator = configuredCoordinator()

        coordinator.send(.push(.settings(.overview)))
        coordinator.send(.push(.settings(.rideDisplay)))
        coordinator.send(.push(.settings(.rideDisplay)))

        #expect(coordinator.state.path == [.settings(.overview), .settings(.rideDisplay)])
        coordinator.send(.pop(ifTop: nil))
        #expect(coordinator.state.path == [.settings(.overview)])
        coordinator.send(.popToRoot)
        #expect(coordinator.state.path.isEmpty)
    }

    @Test("NavigationStack replacement is closed through an intent")
    func replacesPath() {
        let coordinator = configuredCoordinator()
        coordinator.send(.replacePath([.diagnostics(.overview), .batteryHealth(.overview)]))
        #expect(coordinator.state.path == [.diagnostics(.overview), .batteryHealth(.overview)])
    }

    @Test("A delayed close only removes its original top destination")
    func conditionalPopIgnoresAStaleDestination() {
        let coordinator = configuredCoordinator()
        let entryID = UUID()
        let form = AppRoute.maintenance(.form(id: entryID))

        coordinator.send(.push(form))
        coordinator.send(.pop(ifTop: nil))
        coordinator.send(.pop(ifTop: form))

        #expect(coordinator.state.path == [.maintenance(.overview)])
    }

    @Test("Inserts a feature overview before a detail opened from another family")
    func canonicalizesDirectDetailNavigation() {
        let coordinator = configuredCoordinator()
        coordinator.send(.push(.dashboardCards(.section(id: "energy"))))

        #expect(coordinator.state.path == [
            .dashboardCards(.overview),
            .dashboardCards(.section(id: "energy"))
        ])
    }

    @Test("Ride Navigation modes control path and active surfaces")
    func rideNavigationPresentation() {
        let coordinator = configuredCoordinator()
        coordinator.send(.push(.diagnostics(.overview)))
        #expect(coordinator.state.activeSurfaces == [.diagnostics])

        coordinator.send(.showRideNavigation(nil))
        #expect(coordinator.state.activeSurfaces == [.rideNavigation])

        coordinator.send(.minimizeRideNavigation)
        #expect(coordinator.state.path.isEmpty)
        #expect(coordinator.state.activeSurfaces == [.dashboard, .rideNavigation])

        coordinator.send(.push(.settings(.overview)))
        #expect(coordinator.state.rideNavigationMode == .mini)
        #expect(coordinator.state.path == [.settings(.overview)])
        #expect(coordinator.state.activeSurfaces == [.settings, .rideNavigation])

        coordinator.send(.closeRideNavigation)
        #expect(coordinator.state.activeSurfaces == [.settings])
        #expect(coordinator.state.rideNavigationResource == nil)
    }

    @Test("Mini navigation remains active while browsing nested app destinations")
    func miniNavigationAllowsAppNavigation() {
        let coordinator = configuredCoordinator()
        coordinator.send(.showRideNavigation(nil))
        coordinator.send(.minimizeRideNavigation)

        coordinator.send(.push(.settings(.navigation)))
        coordinator.send(.push(.settings(.navigationAppearance)))

        #expect(coordinator.state.rideNavigationMode == .mini)
        #expect(coordinator.state.path == [
            .settings(.overview),
            .settings(.navigation),
            .settings(.navigationAppearance)
        ])
        #expect(coordinator.state.activeSurfaces == [.settings, .rideNavigation])
    }

    @Test("Setup reset clears every navigation surface and pending request")
    func resetSetup() {
        let coordinator = configuredCoordinator()
        coordinator.send(.push(.rideHistory(.overview)))
        coordinator.open(.rideNavigation(resourceURL: URL(string: "https://maps.apple.com")!))
        coordinator.send(.resetSetup)

        #expect(coordinator.state.root == .onboarding)
        #expect(coordinator.state.path.isEmpty)
        #expect(coordinator.state.rideNavigationMode == .hidden)
        #expect(coordinator.state.rideNavigationResource == nil)
    }

    @Test("The latest external request waits until setup completes")
    func latestExternalRequestWinsAfterSetup() {
        let coordinator = AppNavigationCoordinator()
        let first = URL(string: "https://example.com/first")!
        let latest = URL(string: "https://example.com/latest")!

        coordinator.open(.rideNavigation(resourceURL: first))
        coordinator.open(.rideNavigation(resourceURL: latest))
        #expect(coordinator.state.rideNavigationMode == .hidden)

        coordinator.send(.setRoot(.onboarding))
        #expect(coordinator.state.rideNavigationMode == .hidden)
        coordinator.send(.setRoot(.dashboard))

        #expect(coordinator.state.rideNavigationMode == .fullScreen)
        #expect(coordinator.state.rideNavigationResource?.url == latest)
    }

    @Test("Secondary navigation cannot cover loading or onboarding")
    func secondaryNavigationRequiresCompletedSetup() {
        let coordinator = AppNavigationCoordinator()

        coordinator.send(.push(.settings(.overview)))
        coordinator.send(.expandRideNavigation)
        coordinator.send(.replacePath([.diagnostics(.overview)]))
        #expect(coordinator.state.path.isEmpty)
        #expect(coordinator.state.rideNavigationMode == .hidden)

        coordinator.send(.setRoot(.onboarding))
        coordinator.send(.push(.settings(.overview)))
        #expect(coordinator.state.path.isEmpty)
    }

    @Test("Setup reset discards an external request that was still pending")
    func setupResetDiscardsPendingExternalRequest() {
        let coordinator = AppNavigationCoordinator()
        coordinator.open(.rideNavigation(resourceURL: URL(string: "https://example.com/old")!))

        coordinator.send(.resetSetup)
        coordinator.send(.setRoot(.dashboard))

        #expect(coordinator.state.rideNavigationMode == .hidden)
        #expect(coordinator.state.rideNavigationResource == nil)
    }

    private func configuredCoordinator() -> AppNavigationCoordinator {
        let coordinator = AppNavigationCoordinator()
        coordinator.send(.setRoot(.dashboard))
        return coordinator
    }
}

@MainActor
@Suite("App external navigation")
struct AppExternalNavigationTests {
    @Test("Resolves only the existing public entry points")
    func resolvesSupportedURLs() {
        let resolver = AppExternalNavigationResolver()
        let custom = URL(string: "fenr-app://ride-navigation")!
        let gpx = URL(fileURLWithPath: "/tmp/route.gpx")
        let directions = URL(fileURLWithPath: "/tmp/route.directionsrequest")
        let https = URL(string: "https://maps.apple.com/?daddr=40,-3")!

        #expect(resolver.resolve(custom) == .rideNavigation(resourceURL: nil))
        #expect(resolver.resolve(gpx) == .rideNavigation(resourceURL: gpx))
        #expect(resolver.resolve(directions) == .rideNavigation(resourceURL: directions))
        #expect(resolver.resolve(https) == .rideNavigation(resourceURL: https))
        #expect(resolver.resolve(URL(string: "ftp://example.com/route.txt")!) == nil)
        #expect(resolver.resolve(URL(string: "fenr-app://settings")!) == nil)
    }

    @Test("Concurrent consumption is single-flight and sequential activations retry")
    func concurrentConsumptionIsSingleFlight() async {
        let url = URL(string: "https://maps.apple.com/?daddr=40,-3")!
        let store = AppNavigationIncomingMapLinkStore(
            links: [.init(url: url, receivedAt: .distantPast)],
            shouldBlock: true
        )
        var requests: [AppExternalNavigationRequest] = []
        let controller = IncomingMapLinkController(
            store: store,
            resolver: AppExternalNavigationResolver(),
            onRequest: { requests.append($0) }
        )

        let first = Task { await controller.consume() }
        #expect(await waitUntil { await store.isBlocked() })
        let second = Task { await controller.consume() }
        await store.release()
        await first.value
        await second.value
        await controller.consume()

        #expect(await store.consumeCount() == 2)
        #expect(requests == [.rideNavigation(resourceURL: url)])
    }

    @Test("A link received after an empty activation is consumed on the next activation")
    func consumesLinkReceivedAfterEmptyActivation() async {
        let url = URL(fileURLWithPath: "/tmp/shared-route.gpx")
        let store = AppNavigationIncomingMapLinkStore()
        var requests: [AppExternalNavigationRequest] = []
        let controller = IncomingMapLinkController(
            store: store,
            resolver: AppExternalNavigationResolver(),
            onRequest: { requests.append($0) }
        )

        await controller.consume()
        await store.save(.init(url: url, receivedAt: .now))
        await controller.consume()

        #expect(await store.consumeCount() == 2)
        #expect(requests == [.rideNavigation(resourceURL: url)])
    }

    @Test("A storage failure remains retryable")
    func retriesAfterFailure() async {
        let url = URL(string: "https://example.com/route")!
        let store = AppNavigationIncomingMapLinkStore(
            links: [.init(url: url, receivedAt: .distantPast)],
            failures: 1
        )
        var requests: [AppExternalNavigationRequest] = []
        let controller = IncomingMapLinkController(
            store: store,
            resolver: AppExternalNavigationResolver(),
            onRequest: { requests.append($0) }
        )

        await controller.consume()
        await controller.consume()

        #expect(await store.consumeCount() == 2)
        #expect(requests == [.rideNavigation(resourceURL: url)])
    }

    @Test("Cancellation prevents a late consumed link from opening")
    func cancellation() async {
        let url = URL(string: "https://example.com/route")!
        let store = AppNavigationIncomingMapLinkStore(
            links: [.init(url: url, receivedAt: .distantPast)],
            shouldBlock: true
        )
        var requests: [AppExternalNavigationRequest] = []
        let controller = IncomingMapLinkController(
            store: store,
            resolver: AppExternalNavigationResolver(),
            onRequest: { requests.append($0) }
        )

        let consumer = Task { await controller.consume() }
        #expect(await waitUntil { await store.isBlocked() })
        controller.cancel()
        await store.release()
        await consumer.value

        #expect(requests.isEmpty)
    }
}

@MainActor
@Suite("App presentation policy")
struct AppPresentationPolicyTests {
    @Test("Derives orientation and suppresses duplicate requests")
    func orientationAndDeduplication() {
        let spy = AppNavigationOrientationSpy()
        let controller = AppPresentationController(
            policy: AppPresentationPolicy(),
            orientationController: spy
        )
        let navigation = AppNavigationCoordinator()

        controller.update(for: navigation.state)
        controller.update(for: navigation.state)
        navigation.send(.setRoot(.dashboard))
        controller.update(for: navigation.state)
        navigation.send(.push(.settings(.overview)))
        controller.update(for: navigation.state)
        controller.update(for: navigation.state)

        navigation.send(.popToRoot)
        navigation.send(.showRideNavigation(nil))
        navigation.send(.minimizeRideNavigation)
        controller.update(for: navigation.state)
        navigation.send(.push(.settings(.overview)))
        controller.update(for: navigation.state)

        #expect(spy.requests == [.portrait, .landscape, .portrait, .landscape, .portrait])
    }
}

@Suite("App navigation event adapters")
struct AppNavigationEventAdapterTests {
    @Test("Maps every feature event to its root route")
    func mapsFeatureEvents() {
        let rideID = UUID()
        let dashboard = AppNavigationEventAdapter.intent(for: RideDashboardNavigationEvent.openSettings)
        let settings = AppNavigationEventAdapter.intent(for: AppSettingsNavigationEvent.openDashboardCards)
        let settingsDiagnostics = AppNavigationEventAdapter.intent(
            for: AppSettingsNavigationEvent.openDiagnostics
        )
        let cards = AppNavigationEventAdapter.intent(
            for: DashboardCardSettingsNavigationEvent.show(.section(id: "energy"))
        )
        let history = AppNavigationEventAdapter.intent(
            for: RideHistoryNavigationEvent.show(.detail(id: rideID))
        )
        let diagnostics = AppNavigationEventAdapter.intent(
            for: BikeDiagnosticsNavigationEvent.openBatteryHealth
        )
        let battery = AppNavigationEventAdapter.intent(
            for: BatteryHealthNavigationEvent.show(.cells)
        )
        let maintenanceID = UUID()
        let maintenance = AppNavigationEventAdapter.intent(
            for: MaintenanceNavigationEvent.close(.form(id: maintenanceID))
        )

        #expect(dashboard == .push(.settings(.overview)))
        #expect(settings == .push(.dashboardCards(.overview)))
        #expect(settingsDiagnostics == .push(.diagnostics(.overview)))
        #expect(cards == .push(.dashboardCards(.section(id: "energy"))))
        #expect(history == .push(.rideHistory(.detail(id: rideID))))
        #expect(diagnostics == .push(.batteryHealth(.overview)))
        #expect(battery == .push(.batteryHealth(.cells)))
        #expect(maintenance == .pop(ifTop: .maintenance(.form(id: maintenanceID))))
        #expect(AppNavigationEventAdapter.intent(for: AppSettingsNavigationEvent.changeBike) == .popToRoot)
    }
}
