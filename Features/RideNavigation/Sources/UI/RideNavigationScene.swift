import SwiftUI

@MainActor
public struct RideNavigationScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var navigationSurfaceNamespace
    @StateObject private var feature: RideNavigationFeatureModel
    private let presentationMode: RideNavigationPresentationMode
    private let importedURL: URL?
    private let importedURLToken: UUID?
    private let onClose: () -> Void
    private let onMinimize: () -> Void
    private let onExpand: () -> Void

    public init(
        factory: any RideNavigationFeatureBuilding,
        presentationMode: RideNavigationPresentationMode = .fullScreen,
        importedURL: URL? = nil,
        importedURLToken: UUID? = nil,
        onClose: @escaping () -> Void,
        onMinimize: @escaping () -> Void = {},
        onExpand: @escaping () -> Void = {}
    ) {
        _feature = StateObject(wrappedValue: factory.makeFeature())
        self.presentationMode = presentationMode
        self.importedURL = importedURL
        self.importedURLToken = importedURLToken
        self.onClose = onClose
        self.onMinimize = onMinimize
        self.onExpand = onExpand
    }

    public var body: some View {
        Group {
            switch presentationMode {
            case .hidden:
                EmptyView()
            case .fullScreen:
                RideNavigationView(
                    viewModel: feature.viewModel,
                    mapSurfaceFactory: feature.mapSurfaceFactory,
                    transitionNamespace: navigationSurfaceNamespace,
                    onClose: onClose,
                    onMinimize: onMinimize
                )
                .transition(.opacity)
            case .mini:
                RideNavigationMiniScene(
                    viewModel: feature.viewModel,
                    mapSurfaceFactory: feature.mapSurfaceFactory,
                    transitionNamespace: navigationSurfaceNamespace,
                    onExpand: onExpand
                )
                .transition(.opacity)
            }
        }
        .statusBarHidden(presentationMode == .fullScreen)
        .task {
            feature.viewModel.setPresentationMode(presentationMode)
            feature.viewModel.start()
            if let importedURL {
                open(importedURL)
            }
        }
        .onChange(of: presentationMode) {
            feature.viewModel.setPresentationMode(presentationMode)
        }
        .onChange(of: importedURLToken) {
            if let importedURL {
                open(importedURL)
            }
        }
        .onDisappear { feature.viewModel.stop() }
        .animation(presentationTransitionAnimation, value: presentationMode)
    }

    private func open(_ url: URL) {
        if url.pathExtension.lowercased() == "gpx" {
            feature.viewModel.importGPX(from: url)
        } else {
            feature.viewModel.openIncomingMapLink(url)
        }
    }

    private var presentationTransitionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: Constants.reducedPresentationTransitionDuration)
            : .smooth(duration: Constants.presentationTransitionDuration)
    }

    private enum Constants {
        static let presentationTransitionDuration = 0.45
        static let reducedPresentationTransitionDuration = 0.12
    }
}
