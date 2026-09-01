import BikeOnboarding
import Combine
import Foundation
import RideNavigation
import RideNavigationDomain
import SwiftUI
import UIKit

@MainActor
protocol AppRootAnimating {
    func animate(reduceMotion: Bool, updates: () -> Void)
}

@MainActor
struct SwiftUIAppRootAnimator: AppRootAnimating {
    func animate(reduceMotion: Bool, updates: () -> Void) {
        withAnimation(
            reduceMotion
                ? .easeOut(duration: Constants.reducedNavigationTransitionDuration)
                : .smooth(duration: Constants.navigationTransitionDuration),
            updates
        )
    }
}

private extension SwiftUIAppRootAnimator {
    enum Constants {
        static let navigationTransitionDuration = 0.35
        static let reducedNavigationTransitionDuration = 0.12
    }
}

@MainActor
final class AppRootRouter: ObservableObject {
    enum Route: Hashable {
        case onboarding(BikeOnboardingStep)
        case batteryHealth
        case diagnostics
        case settings
        case dashboardCards
        case powerModes
        case rideHistory
        case bikeLockSettings
    }

    struct IncomingNavigationResource: Equatable {
        let id = UUID()
        let url: URL
    }

    @Published var path: [Route] = []
    @Published private(set) var rideNavigationPresentation: RideNavigationPresentationMode
    @Published private(set) var incomingNavigationResource: IncomingNavigationResource?

    private let setupFlow: BikeSetupFlowController
    private let onboardingViewModel: BikeOnboardingViewModel
    private let incomingMapLinkStore: any IncomingMapLinkStoring
    private let interfaceOrientationController: any InterfaceOrientationControlling
    private let animator: any AppRootAnimating
    private var consumeMapLinkTask: Task<Void, Never>?
    private var didConsumeIncomingMapLink = false

    init(
        setupFlow: BikeSetupFlowController,
        onboardingViewModel: BikeOnboardingViewModel,
        incomingMapLinkStore: any IncomingMapLinkStoring,
        interfaceOrientationController: any InterfaceOrientationControlling,
        animator: any AppRootAnimating,
        opensRideNavigationOnLaunch: Bool = false
    ) {
        self.setupFlow = setupFlow
        self.onboardingViewModel = onboardingViewModel
        self.incomingMapLinkStore = incomingMapLinkStore
        self.interfaceOrientationController = interfaceOrientationController
        self.animator = animator
        rideNavigationPresentation = opensRideNavigationOnLaunch ? .fullScreen : .hidden
    }

    deinit {
        consumeMapLinkTask?.cancel()
    }

    func open(_ url: URL, reduceMotion: Bool) {
        if url.scheme?.lowercased() == "fenr-app", url.host?.lowercased() == "ride-navigation" {
            expandRideNavigation(reduceMotion: reduceMotion)
            return
        }
        let scheme = url.scheme?.lowercased()
        let pathExtension = url.pathExtension.lowercased()
        guard pathExtension == "gpx"
            || pathExtension == "directionsrequest"
            || scheme == "https" else { return }
        incomingNavigationResource = .init(url: url)
        expandRideNavigation(reduceMotion: reduceMotion)
    }

    func consumeIncomingMapLink(reduceMotion: Bool) async {
        guard !didConsumeIncomingMapLink else { return }
        if let consumeMapLinkTask {
            await consumeMapLinkTask.value
            return
        }
        let task = Task { @MainActor [weak self, incomingMapLinkStore] in
            do {
                let link = try await incomingMapLinkStore.consume()
                guard let self else { return }
                self.didConsumeIncomingMapLink = true
                if let link {
                    self.open(link.url, reduceMotion: reduceMotion)
                }
            } catch {
                // A failed consume remains retryable on the next activation.
            }
            self?.consumeMapLinkTask = nil
        }
        consumeMapLinkTask = task
        await task.value
    }

    func navigate(to route: Route, reduceMotion: Bool) {
        guard rideNavigationPresentation != .mini else {
            expandRideNavigation(reduceMotion: reduceMotion)
            return
        }
        path.append(route)
        requestOrientation()
    }

    func navigateToOnboardingStep(_ step: BikeOnboardingStep) {
        guard setupFlow.isLoaded, !setupFlow.isCompleted else { return }
        let route = Route.onboarding(step)
        guard path.last != route else { return }
        path.append(route)
        requestOrientation()
    }

    func showRideNavigation(reduceMotion: Bool) {
        expandRideNavigation(reduceMotion: reduceMotion)
    }

    func minimizeRideNavigation(reduceMotion: Bool) {
        animator.animate(reduceMotion: reduceMotion) {
            rideNavigationPresentation = .mini
        }
        requestOrientation()
    }

    func expandRideNavigation(reduceMotion: Bool) {
        animator.animate(reduceMotion: reduceMotion) {
            rideNavigationPresentation = .fullScreen
        }
        requestOrientation()
    }

    func hideRideNavigation(reduceMotion: Bool) {
        animator.animate(reduceMotion: reduceMotion) {
            rideNavigationPresentation = .hidden
        }
        incomingNavigationResource = nil
        requestOrientation()
    }

    func rootPresentationDidStart() {
        synchronizeOnboardingObservation()
        requestOrientation()
    }

    func rootPresentationDidStop() {
        onboardingViewModel.stopObserving()
    }

    func setupStateDidChange() {
        if setupFlow.isCompleted {
            path.removeAll()
        }
        synchronizeOnboardingObservation()
        requestOrientation()
    }

    func pathDidChange() {
        synchronizeOnboardingBackNavigation()
        requestOrientation()
    }

    func onboardingStepDidChange() {
        guard setupFlow.isLoaded, !setupFlow.isCompleted else { return }
        let visibleStep = visibleOnboardingStep
        let viewModelStep = onboardingViewModel.viewState.step
        guard viewModelStep.rawValue > visibleStep.rawValue else { return }
        navigateToOnboardingStep(viewModelStep)
    }

    func changeBikeDidComplete() {
        path.removeAll()
        synchronizeOnboardingObservation()
        requestOrientation()
    }
}

private extension AppRootRouter {
    var visibleOnboardingStep: BikeOnboardingStep {
        if case .onboarding(let step)? = path.last {
            return step
        }
        return .welcome
    }

    func synchronizeOnboardingBackNavigation() {
        guard setupFlow.isLoaded, !setupFlow.isCompleted else { return }
        let visibleStep = visibleOnboardingStep
        while onboardingViewModel.viewState.step.rawValue > visibleStep.rawValue {
            onboardingViewModel.back()
        }
    }

    func synchronizeOnboardingObservation() {
        if setupFlow.isLoaded && !setupFlow.isCompleted {
            onboardingViewModel.startObserving()
        } else {
            onboardingViewModel.stopObserving()
        }
    }

    func requestOrientation() {
        let orientations: UIInterfaceOrientationMask
        if rideNavigationPresentation != .hidden {
            orientations = .landscape
        } else if setupFlow.isCompleted && path.isEmpty {
            orientations = .landscape
        } else {
            orientations = .portrait
        }
        interfaceOrientationController.request(orientations)
    }

}
