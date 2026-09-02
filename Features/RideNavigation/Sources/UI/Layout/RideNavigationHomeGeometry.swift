import DesignSystem
import SwiftUI

enum RideNavigationHomeGeometry {
    static func safeContentFrame(in proxy: GeometryProxy) -> CGRect {
        let insets = proxy.safeAreaInsets
        let margin = DesignSpace.medium
        return CGRect(
            x: insets.leading + margin,
            y: insets.top + margin,
            width: max(.zero, proxy.size.width - insets.leading - insets.trailing - margin * 2),
            height: max(.zero, proxy.size.height - insets.top - insets.bottom - margin * 2)
        )
    }

    static func keyboardDismissButtonPosition(
        in proxy: GeometryProxy,
        keyboardFrame: CGRect,
        buttonSize: CGSize
    ) -> CGPoint {
        let viewFrame = proxy.frame(in: .global)
        return CGPoint(
            x: keyboardFrame.maxX - viewFrame.minX - DesignSpace.medium - buttonSize.width / 2,
            y: keyboardFrame.minY - viewFrame.minY - DesignSpace.medium - buttonSize.height / 2
        )
    }
}
