import SwiftUI

@MainActor
struct DashboardLayoutMetrics {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let speedometerTypeScale: CGFloat

    var centerColumnWidth: CGFloat {
        let equalColumnWidth = size.width / Constants.columnCount
        let desiredWidth = max(
            equalColumnWidth,
            Constants.minimumCenterColumnWidth,
            DashboardSpeedometer.minimumContentWidth(
                for: size,
                dynamicTypeScale: speedometerTypeScale
            )
        )
        let maximumWidth = max(
            equalColumnWidth,
            size.width - (Constants.minimumSideColumnWidth * 2)
        )
        return min(desiredWidth, maximumWidth)
    }

    var sideColumnWidth: CGFloat {
        (size.width - centerColumnWidth) / 2
    }

    var chargingCenterOffset: CGFloat {
        (safeAreaInsets.bottom - safeAreaInsets.top) / 2
    }

    private enum Constants {
        static let columnCount: CGFloat = 3
        static let minimumCenterColumnWidth: CGFloat = 360
        static let minimumSideColumnWidth: CGFloat = 124
    }
}

enum DashboardSideStatusLayoutMetrics {
    static let spacing: CGFloat = 10
    static let secondaryStatusHeight: CGFloat = 64
}
