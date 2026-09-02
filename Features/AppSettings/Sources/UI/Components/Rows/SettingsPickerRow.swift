#if os(iOS)
import DesignSystem
import Foundation
import SwiftUI

struct SettingsPickerRow: View {
    let icon: String
    let iconTint: Color
    let title: LocalizedStringResource
    let selection: Binding<String>
    let options: [AppSettingsOptionViewData]

    var body: some View {
        Picker(selection: selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.id)
            }
        } label: {
            HStack(spacing: DesignSpace.small) {
                SettingsRowIcon(systemName: icon, tint: iconTint)
                Text(title)
            }
        }
        .pickerStyle(.menu)
    }

}
#endif
