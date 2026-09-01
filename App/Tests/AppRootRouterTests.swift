import Foundation
import RideNavigation
import RideNavigationDomain
import Testing
import TestSupport

@MainActor
@Suite("App root router")
struct AppRootRouterTests {
    @Test("Maps navigation deep links and rejects unsupported URLs")
    func mapsNavigationDeepLinksAndRejectsUnsupportedURLs() {
        let fixture = AppRootRouterFixture()

        fixture.router.open(URL(string: "fenr-app://ride-navigation")!, reduceMotion: false)
        #expect(fixture.router.rideNavigationPresentation == .fullScreen)
        fixture.router.hideRideNavigation(reduceMotion: true)

        fixture.router.open(URL(string: "ftp://example.com/route.txt")!, reduceMotion: false)
        #expect(fixture.router.rideNavigationPresentation == .hidden)
        #expect(fixture.router.incomingNavigationResource == nil)

        let mapURL = URL(string: "https://maps.apple.com/?daddr=40,-3")!
        fixture.router.open(mapURL, reduceMotion: false)
        #expect(fixture.router.incomingNavigationResource?.url == mapURL)
        #expect(fixture.router.rideNavigationPresentation == .fullScreen)
    }

    @Test("Consumes a stored map link only once")
    func consumesStoredMapLinkOnlyOnce() async {
        let url = URL(string: "https://maps.apple.com/?daddr=40,-3")!
        let fixture = AppRootRouterFixture(
            links: [.init(url: url, receivedAt: .init(timeIntervalSinceReferenceDate: 0))]
        )

        await fixture.router.consumeIncomingMapLink(reduceMotion: false)
        await fixture.router.consumeIncomingMapLink(reduceMotion: false)

        #expect(await fixture.store.consumeCount() == 1)
        #expect(fixture.router.incomingNavigationResource?.url == url)
    }

    @Test("Routes dashboard and navigation overlay deterministically")
    func routesDashboardAndNavigationOverlayDeterministically() {
        let fixture = AppRootRouterFixture()
        fixture.setupFlow.complete(vin: "FENRTEST000000001")

        fixture.router.navigate(to: .settings, reduceMotion: false)
        #expect(fixture.router.path == [.settings])
        fixture.router.minimizeRideNavigation(reduceMotion: true)
        fixture.router.navigate(to: .diagnostics, reduceMotion: false)

        #expect(fixture.router.path == [.settings])
        #expect(fixture.router.rideNavigationPresentation == .fullScreen)
    }

    @Test("Requests orientation from the root presentation state")
    func requestsOrientationFromRootPresentationState() {
        let fixture = AppRootRouterFixture()

        fixture.router.rootPresentationDidStart()
        fixture.router.showRideNavigation(reduceMotion: true)
        fixture.router.hideRideNavigation(reduceMotion: true)
        fixture.setupFlow.complete(vin: "FENRTEST000000001")
        fixture.router.setupStateDidChange()

        #expect(fixture.orientationController.requests == [
            .portrait,
            .landscape,
            .portrait,
            .landscape
        ])
    }

    @Test("Creator cancellation does not lose consumed link and refocus waiter shares result")
    func creatorCancellationDoesNotLoseConsumedLinkAndRefocusWaiterSharesResult() async {
        let url = URL(string: "https://maps.apple.com/?daddr=40,-3")!
        let fixture = AppRootRouterFixture(
            links: [.init(url: url, receivedAt: .init(timeIntervalSinceReferenceDate: 0))],
            blocksNextConsume: true
        )
        let creator = Task {
            await fixture.router.consumeIncomingMapLink(reduceMotion: false)
        }
        #expect(await waitUntil { await fixture.store.hasPendingConsume() })

        creator.cancel()
        let refocusWaiter = Task {
            await fixture.router.consumeIncomingMapLink(reduceMotion: true)
        }
        await fixture.store.releasePendingConsume()
        await creator.value
        await refocusWaiter.value

        #expect(await fixture.store.consumeCount() == 1)
        #expect(fixture.router.incomingNavigationResource?.url == url)
        #expect(fixture.animator.requests == [false])
    }

    @Test("Failed consumption can retry on refocus")
    func failedConsumptionCanRetryOnRefocus() async {
        let url = URL(string: "https://maps.apple.com/?daddr=40,-3")!
        let fixture = AppRootRouterFixture(
            links: [.init(url: url, receivedAt: .init(timeIntervalSinceReferenceDate: 0))],
            consumeFailures: 1
        )

        await fixture.router.consumeIncomingMapLink(reduceMotion: true)
        #expect(fixture.router.incomingNavigationResource == nil)
        await fixture.router.consumeIncomingMapLink(reduceMotion: false)

        #expect(await fixture.store.consumeCount() == 2)
        #expect(fixture.router.incomingNavigationResource?.url == url)
        #expect(fixture.animator.requests == [false])
    }

    @Test("Deep links, persisted links, and mini expansion honor reduced motion")
    func deepLinksPersistedLinksAndMiniExpansionHonorReducedMotion() async {
        let url = URL(string: "https://maps.apple.com/?daddr=40,-3")!
        let deepLinkFixture = AppRootRouterFixture()
        deepLinkFixture.router.open(url, reduceMotion: true)
        #expect(deepLinkFixture.animator.requests == [true])

        let persistedFixture = AppRootRouterFixture(
            links: [.init(url: url, receivedAt: .init(timeIntervalSinceReferenceDate: 0))]
        )
        await persistedFixture.router.consumeIncomingMapLink(reduceMotion: false)
        #expect(persistedFixture.animator.requests == [false])

        let miniFixture = AppRootRouterFixture()
        miniFixture.router.minimizeRideNavigation(reduceMotion: true)
        miniFixture.router.navigate(to: .settings, reduceMotion: false)
        #expect(miniFixture.animator.requests == [true, false])
        #expect(miniFixture.router.rideNavigationPresentation == .fullScreen)
        #expect(miniFixture.router.path.isEmpty)
    }
}
