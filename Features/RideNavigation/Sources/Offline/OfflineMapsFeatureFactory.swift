import Foundation
import SwiftUI

@MainActor
public struct OfflineMapsFeatureFactory {
    private let builder: @MainActor (UUID?, OfflineMapSelectionSeed?) -> AnyView

    public init(builder: @escaping @MainActor (UUID?, OfflineMapSelectionSeed?) -> AnyView) {
        self.builder = builder
    }

    public func make(routeID: UUID? = nil, seed: OfflineMapSelectionSeed? = nil) -> AnyView {
        builder(routeID, seed)
    }
}
