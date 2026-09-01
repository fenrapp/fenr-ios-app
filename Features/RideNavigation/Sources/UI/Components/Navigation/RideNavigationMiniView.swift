import DesignSystem
import SwiftUI

struct RideNavigationMiniView: View {
    let state: RideNavigationMiniViewState
    let mapSurfaceFactory: RideNavigationMapSurfaceFactory
    let transitionNamespace: Namespace.ID
    let onMove: (RideNavigationMiniViewState.Position) -> Void
    let onResize: (Double) -> Void
    let onToggleOrientation: () -> Void
    let onExpand: () -> Void
    @State private var settledPosition: RideNavigationMiniViewState.Position?
    @State private var settledScale: Double?
    @State private var showsOrientationControl = true
    @State private var orientationInteractionGeneration = 0
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let baseScale = settledScale ?? state.scale
            let displayedScale = Self.clampedScale(
                baseScale * Double(magnification),
                range: state.scaleRange
            )
            let layout = MiniMapLayout(
                proxy: proxy,
                scale: displayedScale,
                isLandscape: state.isLandscape
            )
            let normalizedPosition = settledPosition ?? state.position
            let restingPosition = layout.position(for: normalizedPosition)
            let cardPosition = layout.translatedPosition(
                from: restingPosition,
                by: dragTranslation
            )
            ZStack {
                miniMap
                    .frame(width: layout.cardSize.width, height: layout.cardSize.height)
                    .matchedGeometryEffect(
                        id: Constants.navigationSurfaceID,
                        in: transitionNamespace
                    )
                    .gesture(dragGesture(layout: layout))
                    .simultaneousGesture(magnifyGesture(baseScale: baseScale))
                    .onTapGesture(perform: onExpand)
                    .position(cardPosition)

                orientationButton
                    .position(layout.orientationControlPosition(for: cardPosition))
                    .opacity(showsOrientationControl ? 1 : 0)
                    .scaleEffect(showsOrientationControl ? 1 : Constants.controlTransitionScale)
                    .allowsHitTesting(showsOrientationControl)
                    .accessibilityHidden(!showsOrientationControl)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.smooth(duration: Constants.orientationAnimationDuration), value: state.isLandscape)
        }
        .coordinateSpace(name: Constants.dragCoordinateSpace)
        .task(id: orientationInteractionGeneration) {
            do {
                try await Task.sleep(for: .seconds(Constants.orientationControlDelaySeconds))
                withAnimation(.smooth(duration: Constants.controlTransitionDuration)) {
                    showsOrientationControl = false
                }
            } catch {
                return
            }
        }
    }

    private var orientationButton: some View {
        Button {
            revealOrientationControl()
            onToggleOrientation()
        } label: {
            Image(systemName: state.isLandscape ? "rectangle.portrait.rotate" : "rectangle.landscape.rotate")
                .font(.system(size: Constants.orientationIconSize, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(
                    width: Constants.orientationControlSize,
                    height: Constants.orientationControlSize
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .rideNavigationGlassControl()
        .accessibilityLabel(state.isLandscape ? "Use vertical mini map" : "Use horizontal mini map")
        .accessibilityIdentifier("rideNavigation.miniMap.orientation")
    }

    private var miniMap: some View {
        ZStack(alignment: .top) {
            mapSurfaceFactory.make(
                scene: state.mapScene,
                onIntent: { _ in },
                onInteraction: {}
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            if let statusText = miniStatusText {
                HStack(spacing: DesignSpace.extraSmall) {
                    if let systemImage = miniStatusSystemImage {
                        Image(systemName: systemImage)
                            .accessibilityHidden(true)
                    }
                    Text(statusText)
                }
                    .font(.caption.weight(.bold))
                    .tracking(Constants.statusTracking)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, DesignSpace.small)
                    .padding(.vertical, DesignSpace.extraSmall)
                    .background(Color.white, in: Capsule())
                    .padding(.top, DesignSpace.small)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(Constants.borderOpacity), lineWidth: Constants.borderWidth)
        }
        .shadow(color: .black.opacity(Constants.shadowOpacity), radius: Constants.shadowRadius, y: DesignSpace.small)
        .contentShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityHint("Drag to reposition, pinch to resize, or tap to expand navigation")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Expand navigation"), onExpand)
        .accessibilityIdentifier("rideNavigation.miniMap")
    }

    private var miniStatusText: String? {
        if state.isArrivalPending { return "END REACHED - TAP" }
        if let forkGuidance = state.forkGuidance {
            return [forkGuidance.instructionText, forkGuidance.distanceText]
                .compactMap { $0 }
                .joined(separator: " - ")
        }
        return state.statusText
    }

    private var miniStatusSystemImage: String? {
        if state.isArrivalPending { return "flag.checkered" }
        return state.forkGuidance?.systemImage
    }

    private func dragGesture(layout: MiniMapLayout) -> some Gesture {
        DragGesture(
            minimumDistance: Constants.dragMinimumDistance,
            coordinateSpace: .named(Constants.dragCoordinateSpace)
        )
            .updating($dragTranslation) { value, translation, _ in
                translation = value.translation
            }
            .onEnded { value in
                let restingPosition = layout.position(for: settledPosition ?? state.position)
                let finalPosition = layout.translatedPosition(
                    from: restingPosition,
                    by: value.translation
                )
                let normalizedPosition = layout.normalizedPosition(for: finalPosition)
                settledPosition = normalizedPosition
                onMove(normalizedPosition)
                revealOrientationControl()
            }
    }

    private func magnifyGesture(baseScale: Double) -> some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, magnification, _ in
                magnification = value.magnification
            }
            .onEnded { value in
                let scale = Self.clampedScale(
                    baseScale * Double(value.magnification),
                    range: state.scaleRange
                )
                settledScale = scale
                onResize(scale)
            }
    }

    private static func clampedScale(_ value: Double, range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func revealOrientationControl() {
        withAnimation(.smooth(duration: Constants.controlTransitionDuration)) {
            showsOrientationControl = true
        }
        orientationInteractionGeneration += 1
    }

    private enum Constants {
        static let navigationSurfaceID = "ride-navigation-surface"
        static let dragCoordinateSpace = "ride-navigation-mini-map"
        static let minimumLongEdge: CGFloat = 220
        static let maximumLongEdge: CGFloat = 300
        static let relativeLongEdge: CGFloat = 0.28
        static let aspectRatio: CGFloat = 2 / 3
        static let edgeMargin: CGFloat = 16
        static let cornerRadius: CGFloat = 26
        static let dragMinimumDistance: CGFloat = 8
        static let orientationControlSize: CGFloat = 36
        static let orientationControlGap: CGFloat = 8
        static let orientationControlOverflow = orientationControlSize + orientationControlGap
        static let orientationIconSize: CGFloat = 15
        static let orientationAnimationDuration = 0.3
        static let orientationControlDelaySeconds = 3.0
        static let controlTransitionScale = 0.92
        static let controlTransitionDuration = 0.2
        static let borderWidth: CGFloat = 1
        static let borderOpacity = 0.24
        static let shadowOpacity = 0.4
        static let shadowRadius: CGFloat = 18
        static let statusTracking: CGFloat = 0.7
    }

}

extension RideNavigationMiniView {
    struct MiniMapLayout {
        let cardSize: CGSize
        private let containerSize: CGSize

        init(proxy: GeometryProxy, scale: Double, isLandscape: Bool) {
            self.init(containerSize: proxy.size, scale: scale, isLandscape: isLandscape)
        }

        init(containerSize: CGSize, scale: Double, isLandscape: Bool) {
            let availableWidth = max(containerSize.width - Constants.edgeMargin * 2, 0)
            let availableHeight = max(
                containerSize.height
                    - Constants.edgeMargin * 2
                    - Constants.orientationControlOverflow,
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
                    minimum: Constants.edgeMargin + cardSize.width / 2,
                    maximum: containerSize.width - Constants.edgeMargin - cardSize.width / 2
                ),
                y: constrained(
                    proposedPosition.y,
                    minimum: Constants.edgeMargin
                        + Constants.orientationControlOverflow
                        + cardSize.height / 2,
                    maximum: containerSize.height - Constants.edgeMargin - cardSize.height / 2
                )
            )
        }

        func translatedPosition(from origin: CGPoint, by translation: CGSize) -> CGPoint {
            constrainedPosition(
                CGPoint(
                    x: origin.x + translation.width,
                    y: origin.y + translation.height
                )
            )
        }

        func orientationControlPosition(for cardPosition: CGPoint) -> CGPoint {
            CGPoint(
                x: cardPosition.x,
                y: cardPosition.y
                    - cardSize.height / 2
                    - Constants.orientationControlGap
                    - Constants.orientationControlSize / 2
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
    }
}
