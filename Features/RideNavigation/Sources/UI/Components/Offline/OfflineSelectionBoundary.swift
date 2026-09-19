import DesignSystem
import SwiftUI

struct OfflineSelectionBoundary: View {
    let insets: OfflineMapSelectionInsets

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(
                x: insets.leading, y: insets.top,
                width: max(0, proxy.size.width - insets.leading - insets.trailing),
                height: max(0, proxy.size.height - insets.top - insets.bottom)
            )
            Path { path in
                path.addRect(CGRect(origin: .zero, size: proxy.size))
                path.addRect(rect)
            }
            .fill(.black.opacity(Constants.shadeOpacity), style: FillStyle(eoFill: true))
            Path { $0.addRect(rect) }
                .stroke(.white, lineWidth: Constants.haloWidth)
            Path { $0.addRect(rect) }
                .stroke(DesignColor.accent, lineWidth: Constants.lineWidth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private enum Constants {
        static let shadeOpacity = 0.24
        static let haloWidth = 3.0
        static let lineWidth = 1.5
    }
}
