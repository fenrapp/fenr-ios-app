import SwiftUI

@MainActor
public struct OfflineMapSelectorFactory {
    private let builder: @MainActor (
        OfflineMapSelectionScene, OfflineMapSelectionInsets, @escaping @MainActor (OfflineMapViewport) -> Void
    ) -> AnyView

    public init(builder: @escaping @MainActor (
        OfflineMapSelectionScene, OfflineMapSelectionInsets, @escaping @MainActor (OfflineMapViewport) -> Void
    ) -> AnyView) {
        self.builder = builder
    }

    public func make(
        scene: OfflineMapSelectionScene, insets: OfflineMapSelectionInsets = .init(),
        onViewport: @escaping @MainActor (OfflineMapViewport) -> Void
    ) -> AnyView {
        builder(scene, insets, onViewport)
    }
}
