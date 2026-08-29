import DesignSystem
import SwiftUI

struct RideNavigationMiniView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: RideNavigationMiniViewState
    let mapSurfaceFactory: RideNavigationMapSurfaceFactory
    let transitionNamespace: Namespace.ID
    let onSelectCorner: (RideNavigationMiniViewState.Corner) -> Void
    let onExpand: () -> Void
    @GestureState private var dragTranslation = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let layout = MiniMapLayout(proxy: proxy)
            miniMap
                .frame(width: layout.cardSize.width, height: layout.cardSize.height)
                .position(layout.position(for: state.corner))
                .offset(dragTranslation)
                .matchedGeometryEffect(
                    id: Constants.navigationSurfaceID,
                    in: transitionNamespace
                )
                .gesture(dragGesture(layout: layout))
                .animation(
                    reduceMotion ? nil : .smooth(duration: Constants.snapDuration),
                    value: state.corner
                )
        }
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

            if let statusText = state.statusText {
                Text(statusText)
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
        .accessibilityHint("Double-tap to return to full-screen navigation")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Expand navigation"), onExpand)
        .accessibilityIdentifier("rideNavigation.miniMap")
    }

    private func dragGesture(layout: MiniMapLayout) -> some Gesture {
        DragGesture(minimumDistance: .zero, coordinateSpace: .local)
            .updating($dragTranslation) { value, translation, _ in
                translation = value.translation
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                guard distance >= Constants.tapMaximumTravel else {
                    onExpand()
                    return
                }
                let origin = layout.position(for: state.corner)
                let proposedPosition = CGPoint(
                    x: origin.x + value.translation.width,
                    y: origin.y + value.translation.height
                )
                onSelectCorner(layout.nearestCorner(to: proposedPosition))
            }
    }

    private enum Constants {
        static let navigationSurfaceID = "ride-navigation-surface"
        static let minimumWidth: CGFloat = 220
        static let maximumWidth: CGFloat = 300
        static let relativeWidth = 0.28
        static let aspectRatio = 1.5
        static let edgeMargin: CGFloat = 16
        static let cornerRadius: CGFloat = 26
        static let tapMaximumTravel: CGFloat = 8
        static let snapDuration = 0.35
        static let borderWidth: CGFloat = 1
        static let borderOpacity = 0.24
        static let shadowOpacity = 0.4
        static let shadowRadius: CGFloat = 18
        static let statusTracking: CGFloat = 0.7
    }

    private struct MiniMapLayout {
        let cardSize: CGSize
        private let positions: [RideNavigationMiniViewState.Corner: CGPoint]

        init(proxy: GeometryProxy) {
            let safeWidth = proxy.size.width
                - proxy.safeAreaInsets.leading
                - proxy.safeAreaInsets.trailing
                - Constants.edgeMargin * 2
            let proposedWidth = min(
                max(proxy.size.width * Constants.relativeWidth, Constants.minimumWidth),
                Constants.maximumWidth
            )
            let width = min(proposedWidth, safeWidth)
            let height = width / Constants.aspectRatio
            cardSize = CGSize(width: width, height: height)

            let leadingX = proxy.safeAreaInsets.leading + Constants.edgeMargin + width / 2
            let trailingX = proxy.size.width
                - proxy.safeAreaInsets.trailing
                - Constants.edgeMargin
                - width / 2
            let topY = proxy.safeAreaInsets.top + Constants.edgeMargin + height / 2
            let bottomY = proxy.size.height
                - proxy.safeAreaInsets.bottom
                - Constants.edgeMargin
                - height / 2
            positions = [
                .topLeading: CGPoint(x: leadingX, y: topY),
                .topTrailing: CGPoint(x: trailingX, y: topY),
                .bottomLeading: CGPoint(x: leadingX, y: bottomY),
                .bottomTrailing: CGPoint(x: trailingX, y: bottomY)
            ]
        }

        func position(for corner: RideNavigationMiniViewState.Corner) -> CGPoint {
            positions[corner] ?? .zero
        }

        func nearestCorner(to point: CGPoint) -> RideNavigationMiniViewState.Corner {
            positions.min { lhs, rhs in
                squaredDistance(from: lhs.value, to: point) < squaredDistance(from: rhs.value, to: point)
            }?.key ?? .topTrailing
        }

        private func squaredDistance(from origin: CGPoint, to destination: CGPoint) -> CGFloat {
            let deltaX = destination.x - origin.x
            let deltaY = destination.y - origin.y
            return deltaX * deltaX + deltaY * deltaY
        }
    }
}
