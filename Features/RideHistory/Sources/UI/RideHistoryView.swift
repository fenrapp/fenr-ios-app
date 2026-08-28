import Foundation
import SwiftUI

public struct RideHistoryView: View {
    @ObservedObject private var viewModel: RideHistoryViewModel

    @Environment(\.editMode) private var editMode
    @State private var selectionState = RideHistorySelectionState()

    public init(viewModel: RideHistoryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        RideHistoryList(
            state: viewModel.viewState,
            selectedRideIDs: $selectionState.selectedRideIDs,
            isEditing: isEditing,
            destination: { rideID in
                RideHistoryDetailView(viewModel: viewModel, rideID: rideID)
            },
            refresh: viewModel.refresh,
            deleteRide: viewModel.deleteRide(id:)
        )
            .navigationTitle("Ride History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                RideHistoryEditingToolbar(
                    isVisible: viewModel.viewState.status == .loaded,
                    isEditing: isEditing,
                    availableRideIDs: availableRideIDs,
                    selectedRideIDs: $selectionState.selectedRideIDs,
                    isDeleting: viewModel.viewState.isDeleting,
                    deleteSelection: requestSelectionDeletion
                )
            }
            .task { viewModel.start() }
            .onDisappear { viewModel.stop() }
            .onChange(of: availableRideIDs) { _, availableIDs in
                selectionState.reconcile(availableRideIDs: availableIDs)
            }
            .onChange(of: editMode?.wrappedValue) { _, mode in
                if mode != .active { selectionState.clearSelection() }
            }
            .alert(
                "Delete \(selectionState.pendingDeletionIDs.count) rides?",
                isPresented: bulkDeletionConfirmationBinding
            ) {
                Button("Delete Rides", role: .destructive) {
                    performDeletion(selectionState.pendingDeletionIDs)
                }
                Button("Cancel", role: .cancel) {
                    selectionState.cancelPendingDeletion()
                }
            } message: {
                Text("The selected rides and their saved energy data will be permanently deleted.")
            }
            .alert("Unable to Delete", isPresented: errorBinding) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.viewState.errorMessage ?? "Please try again.")
            }
    }

    private var isEditing: Bool {
        editMode?.wrappedValue == .active
    }

    private var availableRideIDs: Set<UUID> {
        Set(viewModel.viewState.rides.map(\.id))
    }

    private func requestSelectionDeletion() {
        let ids = selectionState.selectedRideIDs
        if selectionState.requiresDeletionConfirmation {
            selectionState.requestDeletionConfirmation()
        } else {
            performDeletion(ids)
        }
    }

    private func performDeletion(_ ids: Set<UUID>) {
        selectionState.finishDeletionRequest()
        editMode?.wrappedValue = .inactive
        viewModel.deleteRides(ids: ids)
    }

    private var bulkDeletionConfirmationBinding: Binding<Bool> {
        .init(
            get: { selectionState.pendingDeletionIDs.count > 1 },
            set: { if !$0 { selectionState.cancelPendingDeletion() } }
        )
    }

    private var errorBinding: Binding<Bool> {
        .init(
            get: { viewModel.viewState.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }

}
