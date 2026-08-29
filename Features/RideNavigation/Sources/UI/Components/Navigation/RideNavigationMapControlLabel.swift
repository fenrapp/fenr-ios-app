import SwiftUI

struct RideNavigationMapControlLabel: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .frame(width: Constants.size, height: Constants.size)
            .contentShape(Circle())
    }

    private enum Constants {
        static let size: CGFloat = 48
    }
}
