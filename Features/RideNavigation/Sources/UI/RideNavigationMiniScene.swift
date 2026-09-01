import SwiftUI

@MainActor
struct RideNavigationMiniScene: View {
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
