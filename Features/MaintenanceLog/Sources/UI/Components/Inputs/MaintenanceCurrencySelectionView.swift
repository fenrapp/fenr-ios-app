import SwiftUI

struct MaintenanceCurrencySelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let options: [MaintenanceFormViewState.CurrencyOption]
    @Binding var selection: String

    var body: some View {
        List(options) { option in
            Button {
                selection = option.id
                dismiss()
            } label: {
                HStack {
                    Text(option.title)
                        .foregroundStyle(.primary)
                    Spacer()
                    if option.id == selection {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(option.id == selection ? .isSelected : [])
        }
        .navigationTitle(.maintenanceFieldCurrency)
        .navigationBarTitleDisplayMode(.inline)
    }
}
