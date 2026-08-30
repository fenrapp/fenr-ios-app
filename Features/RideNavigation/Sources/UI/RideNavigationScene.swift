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

@MainActor
private struct RideNavigationMiniScene: View {
    @ObservedObject var viewModel: RideNavigationViewModel
    let mapSurfaceFactory: RideNavigationMapSurfaceFactory
    let transitionNamespace: Namespace.ID
    let onExpand: () -> Void

    var body: some View {
        RideNavigationMiniView(
            state: viewModel.miniViewState,
            mapSurfaceFactory: mapSurfaceFactory,
            transitionNamespace: transitionNamespace,
            onMove: viewModel.setMiniMapPosition,
            onResize: viewModel.setMiniMapScale,
            onToggleOrientation: viewModel.toggleMiniMapLayoutOrientation,
            onExpand: onExpand
        )
    }
}

public struct RideNavigationView: View {
    @ObservedObject private var viewModel: RideNavigationViewModel
    private let mapSurfaceFactory: RideNavigationMapSurfaceFactory
    private let transitionNamespace: Namespace.ID
    private let onClose: () -> Void
    private let onMinimize: () -> Void
    @State private var showsImporter = false
    @State private var exportDocument: GPXFileDocument?
    @State private var exportFilename = "Ride.gpx"
    @State private var shareRequest: GPXExportRequest?
    @State private var routeName = ""
    @State private var focusInteractionGeneration = 0
    @State private var showsFocusControls = true
    @State private var activeMapSelector: RideNavigationMapSelector?

    public init(
        viewModel: RideNavigationViewModel,
        mapSurfaceFactory: RideNavigationMapSurfaceFactory,
        transitionNamespace: Namespace.ID,
        onClose: @escaping () -> Void,
        onMinimize: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.mapSurfaceFactory = mapSurfaceFactory
        self.transitionNamespace = transitionNamespace
        self.onClose = onClose
        self.onMinimize = onMinimize
    }

    public var body: some View {
        ZStack {
            mapSurfaceFactory.make(
                scene: viewModel.viewState.mapScene,
                onIntent: viewModel.handleMapIntent,
                onInteraction: revealFocusControls
            )
            .id(MapSurfaceIdentity(scene: viewModel.viewState.mapScene))
            .matchedGeometryEffect(
                id: Constants.navigationSurfaceID,
                in: transitionNamespace
            )
            .transition(.opacity)
            .ignoresSafeArea()

            switch viewModel.viewState.screen {
            case .home:
                RideNavigationHomePanel(
                    state: viewModel.viewState,
                    onClose: onClose,
                    onImport: { showsImporter = true },
                    onRecord: viewModel.startRecording,
                    onSearchQueryChanged: viewModel.updateSearchQuery,
                    onSearch: viewModel.search,
                    onSelectSearchResult: viewModel.selectSearchResult,
                    onOpenRoute: viewModel.openSavedRoute,
                    onShareRoute: viewModel.shareSavedRoute,
                    onDeleteRoute: viewModel.deleteSavedRoute
                )
            case .map:
                RideNavigationMapOverlay(
                    state: viewModel.viewState,
                    showsControls: showsFocusControls || !isFocusDriving,
                    onInteraction: revealFocusControls,
                    onClose: closeMap,
                    onStart: viewModel.startPreviewedRoute,
                    onTogglePause: viewModel.toggleRecordingPause,
                    onFinish: viewModel.finishActivity,
                    onMinimize: onMinimize,
                    onReverse: viewModel.toggleRouteDirection,
                    onSelectRouteOption: viewModel.selectRoadRouteOption,
                    onAvoidTolls: viewModel.setAvoidsTolls,
                    onAvoidHighways: viewModel.setAvoidsHighways,
                    onRecenter: { viewModel.handleMapIntent(.recenter) },
                    onOverview: { viewModel.handleMapIntent(.overview) },
                    onMapHeadingUp: viewModel.setMapHeadingUp,
                    onToggleVoice: viewModel.toggleVoice,
                    onMapStyle: viewModel.setMapStyle,
                    activeMapSelector: $activeMapSelector,
                    onFindTrailExit: viewModel.findTrailExit,
                    onCancelTrailExit: viewModel.cancelTrailExitPreview,
                    onStartTrailExit: viewModel.startTrailExit,
                    onResumeGPX: viewModel.resumeGPX,
                    onKeepRidingWithIncomingDestination: viewModel.keepRidingWithIncomingDestination,
                    onEndRideAndOpenIncomingDestination: viewModel.endRideAndOpenIncomingDestination
                )
            case .summary:
                RideNavigationSummaryPanel(
                    state: viewModel.viewState,
                    routeName: $routeName,
                    onSave: { viewModel.saveCompletedRouteAndClose(name: routeName) },
                    onExport: viewModel.exportCompletedRoute,
                    onClose: viewModel.discardActivity
                )
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .task(
            id: FocusAutoHideKey(
                isActive: isFocusDriving,
                isSelectorPresented: activeMapSelector != nil,
                generation: focusInteractionGeneration
            )
        ) {
            guard isFocusDriving, activeMapSelector == nil else {
                withAnimation(.smooth(duration: Constants.focusTransitionDuration)) {
                    showsFocusControls = true
                }
                return
            }
            do {
                try await Task.sleep(for: .seconds(Constants.focusControlsDelaySeconds))
                withAnimation(.smooth(duration: Constants.focusTransitionDuration)) {
                    showsFocusControls = false
                }
            } catch {
                return
            }
        }
        .onChange(of: viewModel.viewState.summaryTitle) {
            if viewModel.viewState.screen == .summary, routeName.isEmpty {
                routeName = "Recorded ride"
            }
        }
        .onChange(of: activeMapSelector) {
            if activeMapSelector != nil {
                revealFocusControls()
            }
        }
        .onChange(of: viewModel.exportRequest) {
            guard let request = viewModel.exportRequest else { return }
            exportFilename = request.filename
            exportDocument = GPXFileDocument(data: request.data)
            viewModel.clearExportRequest()
        }
        .onChange(of: viewModel.shareRequest) {
            guard let request = viewModel.shareRequest else { return }
            shareRequest = request
            viewModel.clearShareRequest()
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.gpx, .xml],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            viewModel.importGPX(from: url)
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: .gpx,
            defaultFilename: exportFilename
        ) { _ in exportDocument = nil }
        .sheet(item: $shareRequest) { request in
            GPXShareSheet(request: request)
        }
        .animation(
            .smooth(duration: Constants.mapTransitionDuration),
            value: MapSurfaceIdentity(scene: viewModel.viewState.mapScene)
        )
    }

    private func closeMap() {
        if viewModel.hasActiveSession {
            viewModel.finishActivity()
        } else {
            viewModel.showHome()
        }
    }

    private var isFocusDriving: Bool {
        viewModel.viewState.mapScene.displayStyle == .focus
            && (viewModel.viewState.activity == .following || viewModel.viewState.activity == .navigating)
    }

    private func revealFocusControls() {
        guard isFocusDriving else { return }
        withAnimation(.smooth(duration: Constants.focusTransitionDuration)) {
            showsFocusControls = true
        }
        focusInteractionGeneration += 1
    }

    private struct FocusAutoHideKey: Hashable {
        let isActive: Bool
        let isSelectorPresented: Bool
        let generation: Int
    }

    private struct MapSurfaceIdentity: Hashable {
        let displayStyle: NavigationMapDisplayStyle
        let sourceID: String

        init(scene: NavigationMapScene) {
            displayStyle = scene.displayStyle
            sourceID = scene.source.id
        }
    }

    private enum Constants {
        static let navigationSurfaceID = "ride-navigation-surface"
        static let focusControlsDelaySeconds = 5.0
        static let focusTransitionDuration = 0.35
        static let mapTransitionDuration = 0.28
    }
}
