import DesignSystem
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
                Form {
                    Section {
                        HStack(spacing: DesignSpace.small) {
                            Image(systemName: detail.symbolName)
                                .font(.title2)
                                .foregroundStyle(.tint)
                            Text(detail.title)
                                .font(.title3.bold())
                        }
                        .padding(.vertical, DesignSpace.extraSmall)
                    }
                    Section(.maintenanceDetailsSection) {
                        ForEach(detail.fields) { field in
                            LabeledContent(field.label, value: field.value)
                        }
                    }
                    if !detail.reminderFields.isEmpty {
                        Section(.maintenanceNextSection) {
                            ForEach(detail.reminderFields) { field in
                                LabeledContent(field.label, value: field.value)
                            }
                        }
                    }
                    if let guidance = detail.officialGuidance {
                        Section(.maintenanceOfficialGuidanceSection) {
                            Label(guidance, systemImage: "book.closed.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button(.maintenanceDeleteEntry, role: .destructive) {
                            confirmsDeletion = true
                        }
                        .disabled(viewModel.isMutating)
                        .accessibilityIdentifier("maintenance.delete.open")
                    }
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
