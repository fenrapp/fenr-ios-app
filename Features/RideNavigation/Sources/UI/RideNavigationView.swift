import SwiftUI

public struct RideNavigationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var viewModel: RideNavigationViewModel
    private let mapSurfaceFactory: RideNavigationMapSurfaceFactory
    private let transitionNamespace: Namespace.ID
    private let onClose: () -> Void
    private let onMinimize: () -> Void
    @State private var showsImporter = false
    @State private var exportDocument: GPXFileDocument?
    @State private var exportFilename = String(localized: .rideNavigationDefaultExportFilename)
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
            .matchedGeometryEffect(id: Constants.navigationSurfaceID, in: transitionNamespace)
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
                    onSelectTrailDirection: viewModel.selectTrailDirection,
                    onCancelTrailDirectionSelection: viewModel.cancelTrailDirectionSelection,
                    onFinishAfterArrival: viewModel.finishAfterTrailArrival,
                    onKeepRidingAfterArrival: viewModel.keepRidingAfterTrailArrival,
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
                    onRetrySave: { viewModel.retryCompletedRouteSave(name: routeName) },
                    onDiscardUnsaved: viewModel.discardUnsavedCompletedRoute,
                    onExport: viewModel.exportCompletedRoute,
                    onClose: viewModel.discardActivity
                )
            }
        }
            .alert(
                Text(.rideNavigationSaveErrorTitle),
                isPresented: Binding(
                    get: { viewModel.settingsSaveError != nil },
                    set: { if !$0 { viewModel.dismissSettingsSaveError() } }
                )
            ) {
                Button(.rideNavigationSaveErrorDismiss) { viewModel.dismissSettingsSaveError() }
            } message: {
                Text(verbatim: viewModel.settingsSaveError ?? "")
            }

        .background(navigationBackground)
        .rideNavigationFocusAppearance(usesFocusAppearance)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .task(id: focusAutoHideKey) {
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
        .onChange(of: viewModel.viewState.screen) {
            if viewModel.viewState.screen == .summary {
                routeName = viewModel.viewState.completedRouteName
                    ?? String(localized: .rideNavigationRecordedRidePlaceholder)
            }
        }
        .onChange(of: activeMapSelector) {
            if activeMapSelector != nil { revealFocusControls() }
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

    private var focusAutoHideKey: FocusAutoHideKey {
        FocusAutoHideKey(
            isActive: isFocusDriving,
            isSelectorPresented: activeMapSelector != nil,
            generation: focusInteractionGeneration
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

    private var navigationBackground: Color {
        guard usesFocusAppearance else { return .black }
        return RideNavigationFocusPalette(colorScheme: colorScheme).background
    }

    private var usesFocusAppearance: Bool {
        viewModel.viewState.mapScene.displayStyle == .focus
    }

    private func revealFocusControls() {
        guard isFocusDriving else { return }
        focusInteractionGeneration += 1
        withAnimation(.smooth(duration: Constants.focusTransitionDuration)) {
            showsFocusControls = true
        }
    }

    private struct FocusAutoHideKey: Hashable {
        let isActive: Bool
        let isSelectorPresented: Bool
        let generation: Int
    }

    private struct MapSurfaceIdentity: Hashable {
        let displayStyle: NavigationMapDisplayStyle
        let sourceID: String
        let showsRoadsInFocus: Bool

        init(scene: NavigationMapScene) {
            displayStyle = scene.displayStyle
            sourceID = scene.source.id
            showsRoadsInFocus = scene.showsRoadsInFocus
        }
    }

    private enum Constants {
        static let navigationSurfaceID = "ride-navigation-surface"
        static let focusControlsDelaySeconds = 5.0
        static let focusTransitionDuration = 0.35
        static let mapTransitionDuration = 0.28
    }
}
