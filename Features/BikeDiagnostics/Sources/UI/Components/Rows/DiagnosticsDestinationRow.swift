import DesignSystem
import SwiftUI

struct DiagnosticsDestinationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        ListNavigationRow(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tint: tint,
            action: action
        )
    }
}
