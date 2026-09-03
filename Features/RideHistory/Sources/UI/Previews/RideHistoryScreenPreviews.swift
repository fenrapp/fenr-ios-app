import SwiftUI

#if DEBUG
#Preview("Ride history") {
    NavigationStack {
        RideHistoryListPreview(isEditing: false)
            .navigationTitle("Ride History")
    }
}

#Preview("Ride history editing") {
    NavigationStack {
        RideHistoryListPreview(isEditing: true)
            .navigationTitle("Ride History")
    }
}

#Preview("Ride detail") {
    NavigationStack {
        RideHistoryDetailContent(state: RideHistoryPreviewData.detailState)
            .navigationTitle("Ride")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Ride history empty") {
    RideHistoryList(
        state: .init(status: .empty),
        selectedRideIDs: .constant([]),
        isEditing: false,
        onOpenRide: { _ in },
        refresh: {},
        deleteRide: { _ in }
    )
}

#Preview("Ride detail accessibility") {
    NavigationStack {
        RideHistoryDetailContent(state: RideHistoryPreviewData.detailState)
            .navigationTitle("Ride")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

private struct RideHistoryListPreview: View {
    let isEditing: Bool

    @State private var selectedRideIDs: Set<UUID>

    init(isEditing: Bool) {
        self.isEditing = isEditing
        _selectedRideIDs = State(initialValue: isEditing ? [RideHistoryPreviewData.firstRideID] : [])
    }

    var body: some View {
        RideHistoryList(
            state: RideHistoryPreviewData.listState,
            selectedRideIDs: $selectedRideIDs,
            isEditing: isEditing,
            onOpenRide: { _ in },
            refresh: {},
            deleteRide: { _ in }
        )
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .toolbar {
            RideHistoryEditingToolbar(
                isVisible: true,
                isEditing: isEditing,
                availableRideIDs: Set(RideHistoryPreviewData.rows.map(\.id)),
                selectedRideIDs: $selectedRideIDs,
                isDeleting: false,
                deleteSelection: {}
            )
        }
    }
}
#endif
