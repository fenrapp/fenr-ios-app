import DesignSystem
import SwiftUI

struct MaintenanceTypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let options: [MaintenanceFormViewState.Option]
    @Binding var selection: String

    var body: some View {
        List(options) { option in
            Button {
                selection = option.id
                dismiss()
            } label: {
                HStack(spacing: DesignSpace.small) {
                    ListRowIcon(systemImage: option.symbolName, tint: DesignColor.informational)
                    VStack(alignment: .leading, spacing: Constants.textSpacing) {
                        Text(option.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(option.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DesignSpace.extraSmall)
                    if option.id == selection {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(DesignColor.informational)
                    }
                }
                .padding(.vertical, Constants.verticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(option.id == selection ? .isSelected : [])
        }
        .navigationTitle(.maintenanceFieldType)
        .navigationBarTitleDisplayMode(.inline)
    }

    private enum Constants {
        static let textSpacing: CGFloat = 3
        static let verticalPadding: CGFloat = 4
    }
}
