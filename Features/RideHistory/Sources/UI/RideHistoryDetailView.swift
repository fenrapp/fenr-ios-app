import Foundation
import SwiftUI

struct RideHistoryDetailView: View {
    @ObservedObject var viewModel: RideHistoryViewModel
    let rideID: UUID

    var body: some View {
        RideHistoryDetailContent(state: viewModel.detailViewState)
        .navigationTitle("Ride")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: rideID) { viewModel.loadDetail(id: rideID) }
        .onDisappear { viewModel.clearDetail(id: rideID) }
    }
}
