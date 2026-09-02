#if os(iOS)
import SwiftUI

struct SettingsRowIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: Constants.side, height: Constants.side)
            .background(tint, in: RoundedRectangle(cornerRadius: Constants.radius, style: .continuous))
            .accessibilityHidden(true)
    }

    private enum Constants {
        static let side: CGFloat = 28
        static let radius: CGFloat = 6
    }
}
#endif
