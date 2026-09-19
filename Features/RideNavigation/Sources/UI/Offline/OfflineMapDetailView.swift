import DesignSystem
import SwiftUI

public struct OfflineMapDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: OfflineDetailViewModel
    @State private var confirmsDeletion = false
    @State private var renamesArea = false
    @State private var showsDetails = true
    private let selector: OfflineMapSelectorFactory

    public init(model: OfflineDetailViewModel, selector: OfflineMapSelectorFactory) {
        _model = State(initialValue: model)
        self.selector = selector
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                if let area = model.area {
                    let landscape = proxy.size.width > proxy.size.height
                    selector.make(scene: OfflineMapSelectionScene(
                        outlines: area.outlines, existing: [], center: nil, isCorridor: true
                    ), insets: mapInsets(landscape: landscape, height: proxy.size.height), onViewport: { _ in })
                    .ignoresSafeArea()
                    .overlay(alignment: landscape ? .trailing : .bottom) {
                        if showsDetails {
                            OfflineAreaInformationPanel(
                                area: area, error: model.errorText, busy: model.isBusy,
                                onPause: model.pause, onResume: model.resume, onExplore: { showsDetails = false }
                            )
                            .frame(width: landscape ? Constants.panelWidth : nil)
                            .frame(maxHeight: landscape ? .infinity : proxy.size.height * Constants.panelFraction)
                            .rideNavigationGlassSurface(cornerRadius: Constants.panelRadius)
                            .padding(DesignSpace.medium)
                        }
                    }
                }
            }
            .navigationTitle(model.area?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .rideNavigationMapToolbar(title: model.area?.name ?? "")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(.offlineDone) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsDetails.toggle() } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel(.offlineMapDetails)
                }
                ToolbarItem(placement: .topBarTrailing) { actionsMenu }
            }
        }
        .ignoresSafeArea(.keyboard)
        .confirmationDialog(.offlineDeleteTitle, isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button(.offlineDelete, role: .destructive, action: model.delete)
            Button(.offlineCancel, role: .cancel) {}
        } message: { Text(.offlineDeleteMessage) }
        .alert(.offlineRenameArea, isPresented: $renamesArea) {
            TextField(text: $model.name) { Text(.offlineAreaLabel) }
            Button(.offlineRename, action: model.rename)
                .disabled(model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(.offlineCancel, role: .cancel) {}
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.didDelete) { if model.didDelete { dismiss() } }
    }

    private var actionsMenu: some View {
        Menu {
            Button { model.name = model.area?.name ?? ""; renamesArea = true } label: {
                Label(.offlineRenameArea, systemImage: "pencil")
            }
            if model.area?.canUpdate == true {
                Button(action: model.update) { Label(.offlineUpdate, systemImage: "arrow.clockwise") }
            }
            Button(role: .destructive) { confirmsDeletion = true } label: {
                Label(.offlineDelete, systemImage: "trash")
            }
        } label: { Image(systemName: "ellipsis") }
        .accessibilityLabel(.offlineAreaActions)
        .disabled(model.isBusy)
    }

    private func mapInsets(landscape: Bool, height: CGFloat) -> OfflineMapSelectionInsets {
        OfflineMapSelectionInsets(
            top: Constants.headerClearance,
            bottom: showsDetails && !landscape ? height * Constants.panelFraction : DesignSpace.large,
            trailing: showsDetails && landscape ? Constants.panelWidth + DesignSpace.large : DesignSpace.large
        )
    }

    private enum Constants {
        static let panelWidth = 350.0
        static let panelRadius = 28.0
        static let panelFraction = 0.48
        static let headerClearance = 64.0
    }
}
