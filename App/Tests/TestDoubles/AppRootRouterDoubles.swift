import BikeDomain
import BikeOnboarding
import Foundation
import RideNavigationDomain
import UIKit

actor AppRootRouterBikeRepository: BikeRepository, BikeDiscoveryRepository {
    func start() async {}
    func stop() async {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { _ in } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { _ in } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { _ in } }
    func startBikeDiscovery() async {}
    func stopBikeDiscovery() async {}
    func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> { .init { _ in } }
}

actor AppRootRouterIncomingMapLinkStore: IncomingMapLinkStoring {
    enum Failure: Error {
        case consumeFailed
    }

    private var links: [IncomingMapLink]
    private var remainingConsumeFailures: Int
    private var blocksNextConsume: Bool
    private var pendingConsume: CheckedContinuation<Void, Never>?
    private var consumes = 0

    init(
        links: [IncomingMapLink] = [],
        consumeFailures: Int = 0,
        blocksNextConsume: Bool = false
    ) {
        self.links = links
        remainingConsumeFailures = consumeFailures
        self.blocksNextConsume = blocksNextConsume
    }

    func save(_ link: IncomingMapLink) {
        links.append(link)
    }

    func consume() async throws -> IncomingMapLink? {
        consumes += 1
        if blocksNextConsume {
            blocksNextConsume = false
            await withCheckedContinuation { pendingConsume = $0 }
        }
        if remainingConsumeFailures > 0 {
            remainingConsumeFailures -= 1
            throw Failure.consumeFailed
        }
        guard !links.isEmpty else { return nil }
        return links.removeFirst()
    }

    func consumeCount() -> Int { consumes }
    func hasPendingConsume() -> Bool { pendingConsume != nil }

    func releasePendingConsume() {
        let continuation = pendingConsume
        pendingConsume = nil
        continuation?.resume()
    }
}

@MainActor
final class AppRootRouterOrientationController: InterfaceOrientationControlling {
    private(set) var requests: [UIInterfaceOrientationMask] = []

    func request(_ policy: UIInterfaceOrientationMask) {
        requests.append(policy)
    }
}

@MainActor
final class AppRootRouterAnimator: AppRootAnimating {
    private(set) var requests: [Bool] = []

    func animate(reduceMotion: Bool, updates: () -> Void) {
        requests.append(reduceMotion)
        updates()
    }
}

@MainActor
struct AppRootRouterFixture {
    let setupFlow: BikeSetupFlowController
    let store: AppRootRouterIncomingMapLinkStore
    let orientationController: AppRootRouterOrientationController
    let animator: AppRootRouterAnimator
    let router: AppRootRouter

    init(
        links: [IncomingMapLink] = [],
        consumeFailures: Int = 0,
        blocksNextConsume: Bool = false
    ) {
        let repository = AppRootRouterBikeRepository()
        let profileRepository = SetupProfileRepository()
        let setupFlow = BikeSetupFlowController(
            useCases: .init(
                load: .init(repository: profileRepository),
                clear: .init(repository: profileRepository)
            ),
            forceOnboarding: true
        )
        let onboardingViewModel = BikeOnboardingDependencyContainer().makeViewModel(
            repository: repository,
            profileRepository: profileRepository,
            initialVIN: nil,
            onCompleted: { vin in setupFlow.complete(vin: vin) }
        )
        let store = AppRootRouterIncomingMapLinkStore(
            links: links,
            consumeFailures: consumeFailures,
            blocksNextConsume: blocksNextConsume
        )
        let orientationController = AppRootRouterOrientationController()
        let animator = AppRootRouterAnimator()
        self.setupFlow = setupFlow
        self.store = store
        self.orientationController = orientationController
        self.animator = animator
        router = AppRootRouter(
            setupFlow: setupFlow,
            onboardingViewModel: onboardingViewModel,
            incomingMapLinkStore: store,
            interfaceOrientationController: orientationController,
            animator: animator
        )
    }
}
