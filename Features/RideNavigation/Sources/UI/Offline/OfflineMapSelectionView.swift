import DesignSystem
import SwiftUI

public struct OfflineMapSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: OfflineSelectionViewModel
    @State private var showsOptions = false
    @State private var promptHeight = Constants.initialPromptHeight
    @State private var latestViewport: OfflineMapViewport?
    private let selector: OfflineMapSelectorFactory

    public init(model: OfflineSelectionViewModel, selector: OfflineMapSelectorFactory) {
        _model = State(initialValue: model)
        self.selector = selector
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                selectionMap(safeArea: proxy.safeAreaInsets)
            }
            .navigationTitle(model.isRoute ? .offlineDownloadRoute : .offlineDownloadArea)
            .navigationBarTitleDisplayMode(.inline)
            .rideNavigationMapToolbar(
                title: String(localized: model.isRoute ? .offlineDownloadRoute : .offlineDownloadArea)
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(.offlineCancel) { model.stop(); dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: model.locate) { Image(systemName: "location") }
                        .accessibilityLabel(.offlineLocate)
                        .disabled(model.scene.center == nil)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showsOptions) {
            OfflineSelectionControls(model: model, onViewLibrary: { model.stop(); dismiss() })
        }
        .onChange(of: showsOptions) {
            if !showsOptions, let latestViewport { model.setViewport(latestViewport) }
        }
        .onAppear { model.start() }
        .onDisappear { if !showsOptions { model.stop() } }
        .onChange(of: model.didEnqueue) { if model.didEnqueue { model.stop(); dismiss() } }
    }

    private func selectionMap(safeArea: EdgeInsets) -> some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            let availableHeight = landscape
                ? proxy.size.height - max(safeArea.top, Constants.mapHeaderClearance)
                    - safeArea.bottom - DesignSpace.large
                : proxy.size.height * Constants.portraitPanelFraction
            let panelHeight = min(promptHeight, max(0, availableHeight))
            let insets = selectionInsets(safeArea: safeArea, landscape: landscape, panelHeight: panelHeight)
            selector.make(scene: model.scene, insets: insets) { viewport in
                latestViewport = viewport
                if !showsOptions { model.setViewport(viewport) }
            }
            .overlay {
                if !model.isRoute { OfflineSelectionBoundary(insets: insets) }
            }
            .overlay(alignment: landscape ? .bottomTrailing : .bottom) {
                ScrollView {
                    selectionPrompt
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { promptHeight = $0 })
                }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: landscape ? Constants.landscapePromptWidth : nil, height: panelHeight)
                    .frame(maxWidth: landscape ? nil : Constants.promptWidth)
                    .padding(.leading, safeArea.leading + DesignSpace.medium)
                    .padding(.trailing, safeArea.trailing + DesignSpace.medium)
                    .padding(.bottom, safeArea.bottom + DesignSpace.medium)
            }
        }
        .ignoresSafeArea()
    }

    private var selectionPrompt: some View {
        VStack(spacing: DesignSpace.small) {
            Text(model.isRoute ? .offlineCorridorInstruction : .offlinePinchInstruction)
                .font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
            if !model.scene.existing.isEmpty {
                Label(.offlineSavedCoverage, systemImage: "square.dashed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button { showsOptions = true } label: {
                Label(.offlineUseThisArea, systemImage: "arrow.right")
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSpace.extraSmall)
            }
            .rideNavigationPrimaryButton()
            .buttonBorderShape(.capsule)
        }
        .padding(DesignSpace.medium)
        .frame(maxWidth: Constants.promptWidth)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
    }

    private func selectionInsets(
        safeArea: EdgeInsets, landscape: Bool, panelHeight: CGFloat
    ) -> OfflineMapSelectionInsets {
        OfflineMapSelectionInsets(
            top: max(safeArea.top, Constants.mapHeaderClearance)
                + (landscape ? DesignSpace.medium : Constants.attributionClearance),
            leading: safeArea.leading + DesignSpace.medium,
            bottom: safeArea.bottom + DesignSpace.medium
                + (landscape ? 0 : panelHeight + DesignSpace.medium),
            trailing: safeArea.trailing + DesignSpace.medium
                + (landscape ? Constants.landscapePromptWidth + DesignSpace.medium : 0)
        )
    }

    private enum Constants {
        static let portraitPanelFraction = 0.45
        static let attributionClearance = 64.0
        static let initialPromptHeight = 150.0
        static let landscapePromptWidth = 300.0
        static let promptWidth = 380.0
        static let cornerRadius = 28.0
        static let mapHeaderClearance = 64.0
    }
}
