import DesignSystem
import SwiftUI

public struct MaintenanceLogView: View {
    @ObservedObject private var viewModel: MaintenanceViewModel
    private let onNavigation: (MaintenanceNavigationEvent) -> Void

    public init(
        viewModel: MaintenanceViewModel,
        onNavigation: @escaping (MaintenanceNavigationEvent) -> Void
    ) {
        self.viewModel = viewModel
        self.onNavigation = onNavigation
    }

    public var body: some View {
        content
            .navigationTitle(.maintenanceTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNavigation(.show(.form(id: nil)))
                    } label: {
                        Label(.maintenanceAdd, systemImage: "plus")
                    }
                    .accessibilityIdentifier("maintenance.add")
                    .disabled(viewModel.viewState.status != .loaded || viewModel.isMutating)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState.status {
        case .bikeUnavailable:
            ContentUnavailableView(
                .maintenanceBikeUnavailable,
                systemImage: "motorcycle",
                description: Text(.maintenanceBikeUnavailableDescription)
            )
        case .loading:
            ProgressView(.maintenanceLoading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if viewModel.viewState.history.isEmpty {
                ContentUnavailableView {
                    Label(.maintenanceEmptyTitle, systemImage: "wrench.and.screwdriver")
                } description: {
                    Text(.maintenanceEmptyDescription)
                } actions: {
                    Button(.maintenanceAddFirst) { onNavigation(.show(.form(id: nil))) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                list
            }
        }
    }

    private var list: some View {
        List {
            if !viewModel.viewState.due.isEmpty {
                Section {
                    ForEach(viewModel.viewState.due) { maintenanceRow($0, showsReminder: true) }
                } header: {
                    Label(.maintenanceDueSection, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            if !viewModel.viewState.upcoming.isEmpty {
                Section(.maintenanceUpcomingSection) {
                    ForEach(viewModel.viewState.upcoming) { maintenanceRow($0, showsReminder: true) }
                }
            }
            Section(.maintenanceHistorySection) {
                ForEach(viewModel.viewState.history) { maintenanceRow($0, showsReminder: false) }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { viewModel.refresh() }
    }

    private func maintenanceRow(
        _ row: MaintenanceLogViewState.Row,
        showsReminder: Bool
    ) -> some View {
        Button {
            onNavigation(.show(.detail(id: row.id)))
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
            Button(role: .destructive) { viewModel.delete(id: row.id) } label: {
                Label(.maintenanceDelete, systemImage: "trash")
            }
        }
    }
}
