import Foundation
import SwiftUI

public struct RideHistoryDetailView: View {
    @ObservedObject private var viewModel: RideHistoryViewModel
    private let rideID: UUID

    public init(viewModel: RideHistoryViewModel, rideID: UUID) {
        self.viewModel = viewModel
        self.rideID = rideID
    }

    public var body: some View {
        RideHistoryDetailContent(state: viewModel.detailViewState)
        .navigationTitle(.rideHistoryRideTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: rideID) { viewModel.loadDetail(id: rideID) }
        .onDisappear { viewModel.clearDetail(id: rideID) }
    }
}
