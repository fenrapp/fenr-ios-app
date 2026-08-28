import Foundation
@testable import RideHistory
import Testing

struct RideHistorySelectionStateTests {
    @Test("Single selection deletes without confirmation")
    func singleSelection() {
        let rideID = UUID()
        var state = RideHistorySelectionState(selectedRideIDs: [rideID])

        #expect(!state.requiresDeletionConfirmation)
        #expect(state.pendingDeletionIDs.isEmpty)

        state.finishDeletionRequest()

        #expect(state.selectedRideIDs.isEmpty)
    }

    @Test("Multiple selection keeps its confirmation payload until completion")
    func multipleSelection() {
        let rideIDs = Set([UUID(), UUID()])
        var state = RideHistorySelectionState(selectedRideIDs: rideIDs)

        #expect(state.requiresDeletionConfirmation)

        state.requestDeletionConfirmation()

        #expect(state.pendingDeletionIDs == rideIDs)

        state.finishDeletionRequest()

        #expect(state.pendingDeletionIDs.isEmpty)
        #expect(state.selectedRideIDs.isEmpty)
    }

    @Test("Unavailable rides are removed from selection and pending deletion")
    func reconcilesAvailableRides() {
        let availableID = UUID()
        let removedID = UUID()
        var state = RideHistorySelectionState(selectedRideIDs: [availableID, removedID])
        state.requestDeletionConfirmation()

        state.reconcile(availableRideIDs: [availableID])

        #expect(state.selectedRideIDs == [availableID])
        #expect(state.pendingDeletionIDs == [availableID])
    }
}
