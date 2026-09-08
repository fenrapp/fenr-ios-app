@testable import WatchOnboarding

@MainActor
enum WatchOnboardingTestFactory {
    static func make(repository: WatchOnboardingRepository) -> WatchOnboardingViewModel {
        WatchOnboardingViewModel(
            useCases: .init(
                connectToBike: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeDebugEvents: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                saveProfile: .init(repository: repository)
            ),
            onCompleted: { _ in }
        )
    }
}
