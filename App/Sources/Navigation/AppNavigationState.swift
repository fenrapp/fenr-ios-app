import Foundation

enum AppRideNavigationMode: Equatable {
    case hidden
    case fullScreen
    case mini
}

enum AppNavigationRoot: Equatable {
    case loading
    case onboarding
    case dashboard
}

enum AppNavigationSurface: Hashable {
    case dashboard
    case settings
    case dashboardCards
    case rideHistory
    case maintenance
    case diagnostics
    case batteryHealth
    case powerModes
    case bikeLockSettings
    case rideNavigation
}

struct AppNavigationResource: Equatable, Identifiable {
    let id: UUID
    let url: URL

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
    }
}

struct AppNavigationState: Equatable {
    private(set) var root: AppNavigationRoot
    private(set) var path: [AppRoute]
    private(set) var rideNavigationMode: AppRideNavigationMode
    private(set) var rideNavigationResource: AppNavigationResource?

    init(
        root: AppNavigationRoot = .loading,
        path: [AppRoute] = [],
        rideNavigationMode: AppRideNavigationMode = .hidden,
        rideNavigationResource: AppNavigationResource? = nil
    ) {
        self.root = root
        self.path = path
        self.rideNavigationMode = rideNavigationMode
        self.rideNavigationResource = rideNavigationResource
    }

    var activeSurfaces: Set<AppNavigationSurface> {
        guard root == .dashboard else { return [] }
        switch rideNavigationMode {
        case .fullScreen:
            return [.rideNavigation]
        case .mini:
            return [.dashboard, .rideNavigation]
        case .hidden:
            return [path.last?.family ?? .dashboard]
        }
    }

    mutating func setRoot(_ root: AppNavigationRoot) {
        self.root = root
    }

    mutating func push(_ route: AppRoute) {
        guard path.last != route else { return }
        path.append(route)
    }

    mutating func replacePath(_ path: [AppRoute]) {
        self.path = path
    }

    mutating func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    mutating func popToRoot() {
        path.removeAll()
    }

    mutating func presentRideNavigation(
        _ mode: AppRideNavigationMode,
        resource: AppNavigationResource? = nil
    ) {
        rideNavigationMode = mode
        if let resource {
            rideNavigationResource = resource
        }
    }

    mutating func clearRideNavigation() {
        rideNavigationMode = .hidden
        rideNavigationResource = nil
    }

    mutating func reset() {
        path.removeAll()
        rideNavigationMode = .hidden
        rideNavigationResource = nil
    }
}
