import DesignSystem
import Foundation
import SwiftUI

struct RideHistoryList<Destination: View>: View {
    let state: RideHistoryViewState
    @Binding var selectedRideIDs: Set<UUID>
    let isEditing: Bool
    let destination: (UUID) -> Destination
    let refresh: () -> Void
    let deleteRide: (UUID) -> Void

    var body: some View {
        switch state.status {
        case .loading:
            ProgressView("Loading ride history")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .bikeUnavailable:
            ContentUnavailableView(
                "Bike Unavailable",
                systemImage: "motorcycle",
                description: Text("Connect or configure a bike to view its saved rides.")
            )
        case .empty:
            ContentUnavailableView(
                "No Saved Rides",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed rides for this bike will appear here.")
            )
        case .loaded:
            list
        }
    }

    private var list: some View {
        List(selection: listSelection) {
            if let summary = state.summary {
                Section {
                    RideHistorySummaryHeader(summary: summary)
                        .padding(.vertical, DesignSpace.extraSmall)
                }
            }

            ForEach(state.daySections) { day in
                Section(day.title) {
                    ForEach(day.rides) { ride in
                        row(ride)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { refresh() }
    }

    @ViewBuilder
    private func row(_ ride: RideHistoryViewState.Row) -> some View {
        if isEditing {
            RideHistoryRow(ride: ride, isDeleting: false)
                .tag(ride.id)
                .disabled(state.isDeleting)
        } else {
            NavigationLink {
                destination(ride.id)
            } label: {
                RideHistoryRow(
                    ride: ride,
                    isDeleting: state.deletingRideIDs.contains(ride.id)
                )
            }
            .disabled(state.isDeleting)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteRide(ride.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(state.isDeleting)
            }
        }
    }

    private var listSelection: Binding<Set<UUID>>? {
        isEditing ? $selectedRideIDs : nil
    }
}
