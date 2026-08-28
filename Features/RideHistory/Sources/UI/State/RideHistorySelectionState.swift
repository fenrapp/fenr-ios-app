import Foundation

struct RideHistorySelectionState {
    var selectedRideIDs: Set<UUID> = []
    private(set) var pendingDeletionIDs: Set<UUID> = []

    var requiresDeletionConfirmation: Bool {
        selectedRideIDs.count > 1
    }

    mutating func reconcile(availableRideIDs: Set<UUID>) {
        selectedRideIDs.formIntersection(availableRideIDs)
        pendingDeletionIDs.formIntersection(availableRideIDs)
    }

    mutating func clearSelection() {
        selectedRideIDs.removeAll()
    }

    mutating func requestDeletionConfirmation() {
        pendingDeletionIDs = selectedRideIDs
    }

    mutating func cancelPendingDeletion() {
        pendingDeletionIDs.removeAll()
    }

    mutating func finishDeletionRequest() {
        pendingDeletionIDs.removeAll()
        selectedRideIDs.removeAll()
    }
}
