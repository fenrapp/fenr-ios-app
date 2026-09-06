import Foundation
import SwiftUI

public struct MaintenanceDetailView: View {
    @ObservedObject private var viewModel: MaintenanceViewModel
    private let entryID: UUID
    private let onNavigation: (MaintenanceNavigationEvent) -> Void
    @State private var confirmsDeletion = false

    public init(
        viewModel: MaintenanceViewModel,
        entryID: UUID,
        onNavigation: @escaping (MaintenanceNavigationEvent) -> Void
    ) {
        self.viewModel = viewModel
        self.entryID = entryID
        self.onNavigation = onNavigation
    }

    public var body: some View {
        Group {
            if let detail = viewModel.detail(id: entryID) {
                MaintenanceDetailContent(detail: detail, isMutating: viewModel.isMutating) {
                    confirmsDeletion = true
                }
                .navigationTitle(.maintenanceDetailTitle)
                .toolbar {
                    Button(.maintenanceEdit) { onNavigation(.show(.form(id: entryID))) }
                        .disabled(viewModel.isMutating)
                        .accessibilityIdentifier("maintenance.edit")
                }
            } else {
                ContentUnavailableView(.maintenanceNotFound, systemImage: "wrench.and.screwdriver")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(.maintenanceDeleteConfirmation, isPresented: $confirmsDeletion) {
            Button(.maintenanceDeleteEntry, role: .destructive) {
                viewModel.delete(id: entryID) {
                    onNavigation(.close(.detail(id: entryID)))
                }
            }
            .accessibilityIdentifier("maintenance.delete.confirm")
            Button(.maintenanceCancel, role: .cancel) {}
                .accessibilityIdentifier("maintenance.delete.cancel")
        }
    }
}
