import RideNavigation
import SwiftUI

struct FocusNavigationMapView: View {
    let scene: NavigationMapScene
    let onIntent: (NavigationMapIntent) -> Void
    let onInteraction: () -> Void
    @State private var renderer: FocusNavigationRenderer
    @State private var settledTranslation = CGSize.zero
    @State private var settledScale = 1.0
    @State private var lastConcreteCamera = NavigationMapCamera.automatic
    @State private var isDragging = false
    @State private var isMagnifying = false
    @GestureState private var dragTranslation = CGSize.zero
    @GestureState private var gestureScale = 1.0

    init(
        scene: NavigationMapScene,
        renderer: FocusNavigationRenderer,
        onIntent: @escaping (NavigationMapIntent) -> Void,
        onInteraction: @escaping () -> Void
    ) {
        self.scene = scene
        _renderer = State(initialValue: renderer)
        self.onIntent = onIntent
        self.onInteraction = onInteraction
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black
                Canvas { context, size in
                    let viewport = FocusNavigationViewport(scene: scene, camera: effectiveCamera, size: size)
                    renderer.draw(scene: scene, in: &context, viewport: viewport)
                }
                .scaleEffect(effectiveScale)
                .offset(effectiveTranslation)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onInteraction)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .onAppear { lastConcreteCamera = scene.camera }
            .onChange(of: scene.camera) { oldCamera, newCamera in
                guard !isUserControlled(newCamera) else { return }
                lastConcreteCamera = newCamera
                guard isUserControlled(oldCamera) else { return }
                resetViewportInteraction()
            }
            .accessibilityElement()
            .accessibilityLabel(.rideNavigationAppleMapsFocusMapAccessibility)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: Constants.interactionMinimumDistance)
            .updating($dragTranslation) { value, translation, _ in translation = value.translation }
            .onChanged { _ in
                guard !isDragging else { return }
                isDragging = true
                beginMapInteraction()
            }
            .onEnded { value in
                settledTranslation.width += value.translation.width
                settledTranslation.height += value.translation.height
                isDragging = false
                onInteraction()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, scale, _ in scale = value.magnification }
            .onChanged { _ in
                guard !isMagnifying else { return }
                isMagnifying = true
                beginMapInteraction()
            }
            .onEnded { value in
                settledScale = clampedScale(settledScale * value.magnification)
                isMagnifying = false
                onInteraction()
            }
    }

    private var effectiveCamera: NavigationMapCamera {
        isUserControlled(scene.camera) ? lastConcreteCamera : scene.camera
    }

    private var effectiveTranslation: CGSize {
        CGSize(
            width: settledTranslation.width + dragTranslation.width,
            height: settledTranslation.height + dragTranslation.height
        )
    }

    private var effectiveScale: Double { clampedScale(settledScale * gestureScale) }

    private func beginMapInteraction() {
        onInteraction()
        guard !isUserControlled(scene.camera) else { return }
        lastConcreteCamera = scene.camera
        onIntent(.userMovedCamera)
    }

    private func resetViewportInteraction() {
        settledTranslation = .zero
        settledScale = 1
    }

    private func clampedScale(_ value: Double) -> Double {
        min(max(value, Constants.minimumUserScale), Constants.maximumUserScale)
    }

    private func isUserControlled(_ camera: NavigationMapCamera) -> Bool {
        if case .userControlled = camera { return true }
        return false
    }

    private enum Constants {
        static let interactionMinimumDistance: CGFloat = 8
        static let minimumUserScale = 0.65
        static let maximumUserScale = 3.0
    }
}
