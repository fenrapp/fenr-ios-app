import DesignSystem
import Foundation
import SwiftUI

struct RideHistoryList: View {
    let state: RideHistoryViewState
    @Binding var selectedRideIDs: Set<UUID>
    let isEditing: Bool
    let onOpenRide: (UUID) -> Void
    let refresh: () -> Void
    let deleteRide: (UUID) -> Void

    var body: some View {
        switch state.status {
        case .loading:
            ProgressView(.rideHistoryLoading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .bikeUnavailable:
            ContentUnavailableView(
                .rideHistoryBikeUnavailable,
                systemImage: "motorcycle",
                description: Text(.rideHistoryBikeUnavailableDescription)
            )
        case .empty:
            ContentUnavailableView(
                .rideHistoryNoSavedRides,
                systemImage: "clock.arrow.circlepath",
                description: Text(.rideHistoryNoSavedRidesDescription)
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
            Button {
                onOpenRide(ride.id)
            } label: {
                HStack(spacing: DesignSpace.extraSmall) {
                    RideHistoryRow(
                        ride: ride,
                        isDeleting: state.deletingRideIDs.contains(ride.id)
                    )
                    Spacer(minLength: DesignSpace.extraSmall)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
            .disabled(state.isDeleting)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteRide(ride.id)
                } label: {
                    Label(.rideHistoryDelete, systemImage: "trash")
                }
                .disabled(state.isDeleting)
            }
        }
    }

    private var listSelection: Binding<Set<UUID>>? {
        isEditing ? $selectedRideIDs : nil
    }
}
