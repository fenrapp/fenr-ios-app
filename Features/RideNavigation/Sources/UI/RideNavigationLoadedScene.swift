import SwiftUI

@MainActor
struct RideNavigationLoadedScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var navigationSurfaceNamespace
    let feature: RideNavigationFeatureModel
    let presentationMode: RideNavigationPresentationMode
    let importedURL: URL?
    let importedURLToken: UUID?
    let onNavigation: (RideNavigationPresentationEvent) -> Void

    var body: some View {
        Group {
            switch presentationMode {
            case .hidden:
                EmptyView()
            case .fullScreen:
                RideNavigationView(
                    viewModel: feature.viewModel,
                    mapSurfaceFactory: feature.mapSurfaceFactory,
                    transitionNamespace: navigationSurfaceNamespace,
                    onClose: { onNavigation(.close) },
                    onMinimize: { onNavigation(.minimize) }
                )
                .transition(.opacity)
            case .mini:
                RideNavigationMiniScene(
                    viewModel: feature.viewModel,
                    mapSurfaceFactory: feature.mapSurfaceFactory,
                    transitionNamespace: navigationSurfaceNamespace,
                    onExpand: { onNavigation(.expand) }
                )
                .transition(.opacity)
            }
        }
        .statusBarHidden(presentationMode == .fullScreen)
        .task {
            guard !Task.isCancelled else { return }
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
