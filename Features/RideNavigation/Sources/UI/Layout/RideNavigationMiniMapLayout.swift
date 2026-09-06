import DesignSystem
import SwiftUI

struct RideNavigationMiniMapLayout {
    static let orientationControlHitSize: CGFloat = 44
    let cardSize: CGSize
    private let containerSize: CGSize

    init(proxy: GeometryProxy, scale: Double, isLandscape: Bool) {
        self.init(containerSize: proxy.size, scale: scale, isLandscape: isLandscape)
    }

    init(containerSize: CGSize, scale: Double, isLandscape: Bool) {
        let availableWidth = max(containerSize.width - DesignSpace.medium * 2, 0)
        let availableHeight = max(
            containerSize.height - DesignSpace.medium * 2 - Constants.dashboardHeaderClearance,
            0
        )
        let baseLongEdge = min(
            max(containerSize.width * Constants.relativeLongEdge, Constants.minimumLongEdge),
            Constants.maximumLongEdge
        )
        let longEdge = baseLongEdge * CGFloat(scale)
        let proposedSize = isLandscape
            ? CGSize(width: longEdge, height: longEdge * Constants.aspectRatio)
            : CGSize(width: longEdge * Constants.aspectRatio, height: longEdge)
        let fitScale = min(
            1,
            availableWidth / max(proposedSize.width, 1),
            availableHeight / max(proposedSize.height, 1)
        )
        cardSize = CGSize(
            width: proposedSize.width * fitScale,
            height: proposedSize.height * fitScale
        )
        self.containerSize = containerSize
    }

    func position(for normalizedPosition: RideNavigationMiniViewState.Position) -> CGPoint {
        constrainedPosition(CGPoint(
            x: containerSize.width * CGFloat(normalizedPosition.horizontalFraction),
            y: containerSize.height * CGFloat(normalizedPosition.verticalFraction)
        ))
    }

    func constrainedPosition(_ proposedPosition: CGPoint) -> CGPoint {
        CGPoint(
            x: constrained(
                proposedPosition.x,
                minimum: DesignSpace.medium + cardSize.width / 2,
                maximum: containerSize.width - DesignSpace.medium - cardSize.width / 2
            ),
            y: constrained(
                proposedPosition.y,
                minimum: DesignSpace.medium + Constants.dashboardHeaderClearance + cardSize.height / 2,
                maximum: containerSize.height - DesignSpace.medium - cardSize.height / 2
            )
        )
    }

    func translatedPosition(from origin: CGPoint, by translation: CGSize) -> CGPoint {
        constrainedPosition(CGPoint(
            x: origin.x + translation.width,
            y: origin.y + translation.height
        ))
    }

    func orientationControlPosition(for cardPosition: CGPoint) -> CGPoint {
        CGPoint(
            x: cardPosition.x + cardSize.width / 2
                - DesignSpace.extraSmall - Self.orientationControlHitSize / 2,
            y: cardPosition.y
        )
    }

    func normalizedPosition(for proposedPosition: CGPoint) -> RideNavigationMiniViewState.Position {
        let position = constrainedPosition(proposedPosition)
        return RideNavigationMiniViewState.Position(
            horizontalFraction: fraction(value: position.x, total: containerSize.width),
            verticalFraction: fraction(value: position.y, total: containerSize.height)
        )
    }

    private func constrained(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard minimum <= maximum else { return (minimum + maximum) / 2 }
        return min(max(value, minimum), maximum)
    }

    private func fraction(value: CGFloat, total: CGFloat) -> Double {
        guard total > 0 else { return 0.5 }
        return Double(value / total)
    }

    private enum Constants {
        static let minimumLongEdge: CGFloat = 220
        static let maximumLongEdge: CGFloat = 300
        static let relativeLongEdge: CGFloat = 0.28
        static let aspectRatio: CGFloat = 2 / 3
        static let dashboardHeaderClearance: CGFloat = 44
    }
}
