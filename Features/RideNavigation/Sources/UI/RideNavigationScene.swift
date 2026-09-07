import SwiftUI

@MainActor
public struct RideNavigationScene: View {
    @State private var feature: RideNavigationFeatureModel?
    private let factory: any RideNavigationFeatureBuilding
    private let presentationMode: RideNavigationPresentationMode
    private let importedURL: URL?
    private let importedURLToken: UUID?
    private let onNavigation: (RideNavigationPresentationEvent) -> Void

    public init(
        factory: any RideNavigationFeatureBuilding,
        presentationMode: RideNavigationPresentationMode = .fullScreen,
        importedURL: URL? = nil,
        importedURLToken: UUID? = nil,
        onNavigation: @escaping (RideNavigationPresentationEvent) -> Void
    ) {
        self.factory = factory
        self.presentationMode = presentationMode
        self.importedURL = importedURL
        self.importedURLToken = importedURLToken
        self.onNavigation = onNavigation
    }

    public var body: some View {
        Group {
            if let feature {
                RideNavigationLoadedScene(
                    feature: feature,
                    presentationMode: presentationMode,
                    importedURL: importedURL,
                    importedURLToken: importedURLToken,
                    onNavigation: onNavigation
                )
            } else {
                ProgressView()
            }
        }
        .task {
            guard !Task.isCancelled else { return }
            if feature == nil { feature = factory.makeFeature() }
        }
    }
}
