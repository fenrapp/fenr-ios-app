import DesignSystem
import SwiftUI

struct MaintenanceDetailContent: View {
    let detail: MaintenanceDetailViewState
    let isMutating: Bool
    let onDelete: () -> Void

    var body: some View {
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
                        .accessibilityIdentifier("maintenance.detail.\(field.id)")
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
                    onDelete()
                }
                .disabled(isMutating)
                .accessibilityIdentifier("maintenance.delete.open")
            }
        }
    }
}
