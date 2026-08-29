import SwiftUI

@MainActor
public struct RideNavigationMapSurfaceFactory {
    private let makeView: @MainActor (
        NavigationMapScene,
        @escaping @MainActor (NavigationMapIntent) -> Void,
        @escaping @MainActor () -> Void
    ) -> AnyView

    public init(
        makeView: @escaping @MainActor (
            NavigationMapScene,
            @escaping @MainActor (NavigationMapIntent) -> Void,
            @escaping @MainActor () -> Void
        ) -> AnyView
    ) {
        self.makeView = makeView
    }

    public func make(
        scene: NavigationMapScene,
        onIntent: @escaping @MainActor (NavigationMapIntent) -> Void,
        onInteraction: @escaping @MainActor () -> Void
    ) -> AnyView {
        makeView(scene, onIntent, onInteraction)
    }
}
