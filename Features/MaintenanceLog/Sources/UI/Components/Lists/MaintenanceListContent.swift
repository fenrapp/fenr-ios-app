import DesignSystem
import Foundation
import SwiftUI

struct MaintenanceListContent: View {
    let state: MaintenanceLogViewState
    let onAdd: () -> Void
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onRefresh: () -> Void

    @ViewBuilder
    var body: some View {
        switch state.status {
        case .bikeUnavailable:
            ContentUnavailableView(
                .maintenanceBikeUnavailable,
                systemImage: "motorcycle",
                description: Text(.maintenanceBikeUnavailableDescription)
            )
        case .failed:
            ContentUnavailableView {
                Label(.maintenanceReadErrorTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(verbatim: state.loadErrorMessage ?? "")
            } actions: {
                Button(.maintenanceRetry, action: onRefresh)
                    .accessibilityIdentifier("maintenance.retry")
            }
        case .loading:
            ProgressView(.maintenanceLoading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if state.history.isEmpty {
                VStack {
                    if let message = state.loadErrorMessage {
                        MaintenanceReadErrorNotice(message: message, retry: onRefresh)
                            .padding(DesignSpace.medium)
                    }
                    ContentUnavailableView {
                        Label(.maintenanceEmptyTitle, systemImage: "wrench.and.screwdriver")
                    } description: {
                        Text(.maintenanceEmptyDescription)
                    } actions: {
                        Button(.maintenanceAddFirst) { onAdd() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                list
            }
        }
    }

    private var list: some View {
        List {
            if let message = state.loadErrorMessage {
                Section { MaintenanceReadErrorNotice(message: message, retry: onRefresh) }
            }
            if !state.due.isEmpty {
                Section {
                    ForEach(state.due) { maintenanceRow($0, showsReminder: true) }
                } header: {
                    Label(.maintenanceDueSection, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(DesignColor.critical)
                }
            }
            if !state.upcoming.isEmpty {
                Section(.maintenanceUpcomingSection) {
                    ForEach(state.upcoming) { maintenanceRow($0, showsReminder: true) }
                }
            }
            Section(.maintenanceHistorySection) {
                ForEach(state.history) { maintenanceRow($0, showsReminder: false) }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { onRefresh() }
    }

    private func maintenanceRow(
        _ row: MaintenanceLogViewState.Row,
        showsReminder: Bool
    ) -> some View {
        Button {
            onSelect(row.id)
        } label: {
            HStack(spacing: DesignSpace.extraSmall) {
                MaintenanceRow(row: row, showsReminder: showsReminder)
                Spacer(minLength: DesignSpace.extraSmall)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("maintenance.row")
        .swipeActions {
            Button(role: .destructive) { onDelete(row.id) } label: {
                Label(.maintenanceDelete, systemImage: "trash")
            }
        }
    }
}
