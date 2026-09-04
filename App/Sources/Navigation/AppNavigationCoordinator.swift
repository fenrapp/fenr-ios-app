import Combine
import Foundation

@MainActor
final class AppNavigationCoordinator: ObservableObject {
    @Published private(set) var state: AppNavigationState

    private var pendingExternalRequest: AppExternalNavigationRequest?

    init(opensRideNavigationOnLaunch: Bool = false) {
        state = AppNavigationState()
        if opensRideNavigationOnLaunch {
            pendingExternalRequest = .rideNavigation(resourceURL: nil)
        }
    }

    func send(_ intent: AppNavigationIntent) {
        switch intent {
        case .push(let route):
            guard state.root == .dashboard else { return }
            guard state.rideNavigationMode != .mini else {
                state.presentRideNavigation(.fullScreen)
                return
            }
            pushCanonical(route)
        case .replacePath(let path):
            state.replacePath(state.root == .dashboard ? canonicalized(path) : [])
        case .pop(let expectedTop):
            guard expectedTop == nil || state.path.last == expectedTop else { return }
            state.pop()
        case .popToRoot:
            state.popToRoot()
        case .showRideNavigation(let request):
            open(request ?? .rideNavigation(resourceURL: nil))
        case .minimizeRideNavigation:
            guard state.root == .dashboard else { return }
            state.popToRoot()
            state.presentRideNavigation(.mini)
        case .expandRideNavigation:
            guard state.root == .dashboard else { return }
            state.presentRideNavigation(.fullScreen)
        case .closeRideNavigation:
            state.clearRideNavigation()
        case .setRoot(let root):
            updateRoot(root)
        case .resetSetup:
            pendingExternalRequest = nil
            state.reset()
            state.setRoot(.onboarding)
        }
    }

    func open(_ request: AppExternalNavigationRequest) {
        guard state.root == .dashboard else {
            pendingExternalRequest = request
            return
        }
        execute(request)
    }
}

private extension AppNavigationCoordinator {
    func updateRoot(_ root: AppNavigationRoot) {
        guard state.root != root else { return }
        state.setRoot(root)
        guard root == .dashboard else {
            state.reset()
            state.setRoot(root)
            return
        }

        state.popToRoot()
        if let pendingExternalRequest {
            self.pendingExternalRequest = nil
            execute(pendingExternalRequest)
        }
    }

    func execute(_ request: AppExternalNavigationRequest) {
        switch request {
        case .rideNavigation(let resourceURL):
            let resource = resourceURL.map { AppNavigationResource(url: $0) }
            state.presentRideNavigation(.fullScreen, resource: resource)
        }
    }

    func pushCanonical(_ route: AppRoute) {
        if let parent = route.canonicalParent,
           state.path.last?.family != route.family {
            state.push(parent)
        }
        state.push(route)
    }

    func canonicalized(_ path: [AppRoute]) -> [AppRoute] {
        var canonicalPath: [AppRoute] = []
        for route in path {
            if let parent = route.canonicalParent,
               canonicalPath.last?.family != route.family {
                canonicalPath.append(parent)
            }
            if canonicalPath.last != route {
                canonicalPath.append(route)
            }
        }
        return canonicalPath
    }
}
