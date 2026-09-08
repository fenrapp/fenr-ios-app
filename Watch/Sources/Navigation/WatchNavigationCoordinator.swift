import Observation
import WatchDashboard

enum WatchNavigationRoot: Equatable {
    case loading
    case onboarding
    case dashboard
}

enum WatchRoute: Hashable {
    case settings
}

enum WatchNavigationIntent: Equatable {
    case setRoot(WatchNavigationRoot)
    case push(WatchRoute)
    case replacePath([WatchRoute])
    case pop
    case resetSetup
}

enum WatchNavigationEventAdapter {
    static func intent(for event: WatchDashboardNavigationEvent) -> WatchNavigationIntent? {
        switch event {
        case .openSettings: .push(.settings)
        case .changeBike: nil
        }
    }
}

struct WatchNavigationState: Equatable {
    private(set) var root: WatchNavigationRoot = .loading
    private(set) var path: [WatchRoute] = []

    mutating func setRoot(_ root: WatchNavigationRoot) {
        self.root = root
        if root != .dashboard { path.removeAll() }
    }

    mutating func push(_ route: WatchRoute) {
        guard path.last != route else { return }
        path.append(route)
    }

    mutating func replacePath(_ path: [WatchRoute]) {
        self.path = path
    }

    mutating func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

@MainActor
@Observable
final class WatchNavigationCoordinator {
    private(set) var state = WatchNavigationState()

    func send(_ intent: WatchNavigationIntent) {
        switch intent {
        case .setRoot(let root):
            state.setRoot(root)
        case .push(let route):
            guard state.root == .dashboard else { return }
            state.push(route)
        case .replacePath(let path):
            state.replacePath(state.root == .dashboard ? path : [])
        case .pop:
            state.pop()
        case .resetSetup:
            state.setRoot(.onboarding)
        }
    }
}
