import SwiftUI

@MainActor
struct RideNavigationMiniScene: View {
    let viewModel: RideNavigationViewModel
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
    }
}
