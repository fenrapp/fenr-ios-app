#if os(iOS)
import Foundation
import SwiftUI

struct SettingsSelectionPicker: View {
    let title: LocalizedStringResource
    let selection: AppSettingsSelectionViewState
    let onSelect: (String) -> Void

    var body: some View {
        Picker(title, selection: Binding(
            get: { selection.selectedID }, set: { onSelect($0) }
        )) {
            ForEach(selection.options) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }
}
#endif
