import SwiftUI

@MainActor
public struct OfflineMapThumbnailFactory {
    private let builder: @MainActor (OfflineAreaRow) -> AnyView

    public init(builder: @escaping @MainActor (OfflineAreaRow) -> AnyView) {
        self.builder = builder
    }

    public func make(area: OfflineAreaRow) -> AnyView { builder(area) }
}
