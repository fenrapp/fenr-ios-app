import BikeDemo
import DesignSystem
import SwiftUI

struct AppExperienceView: View {
    @ObservedObject var controller: AppExperienceController

    var body: some View {
        Group {
            if let experience = controller.experience {
                AppExperienceContent(experience: experience, controller: controller)
                    .id(experience.id)
                    .disabled(controller.isBusy)
            } else if controller.failure == .storage {
                ContentUnavailableView {
                    Label(.appStorageRecoveryTitle, systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(.appStorageRecoveryDetail)
                } actions: {
                    Button(action: controller.restore) {
                        Text(.appStorageRetry)
                            .frame(minWidth: Constants.minimumTouchTarget, minHeight: Constants.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("app.storageRecovery.retry")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("app.storageRecovery")
            } else if controller.hasError {
                ContentUnavailableView {
                    Label(.appDemoRecoveryTitle, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(.appDemoRecoveryDetail)
                } actions: {
                    Button(.appDemoRetry, action: controller.restore)
                    Button(.appDemoBackToSetup, action: controller.changeBike)
                }
            } else {
                ProgressView()
            }
        }
        .overlay {
            if controller.isBusy { ProgressView().controlSize(.large) }
        }
        .alert(Text(.appDemoRecoveryTitle), isPresented: Binding(
            get: { controller.hasError && !controller.showsIntroduction && controller.experience != nil },
            set: { _ in }
        )) {
            Button(.appDemoBackToSetup, action: controller.changeBike)
        } message: {
            Text(.appDemoRecoveryDetail)
        }
        .sheet(isPresented: $controller.showsIntroduction, onDismiss: controller.cancelIntroduction) {
            BikeDemoIntroductionView(
                isBusy: controller.isBusy, hasError: controller.hasError,
                onStart: controller.startDemo, onCancel: controller.cancelIntroduction
            )
        }
        .task { controller.restore() }
    }

    private enum Constants {
        static let minimumTouchTarget: CGFloat = 44
    }
}

private struct AppExperienceContent: View {
    let experience: AppExperience
    @ObservedObject var controller: AppExperienceController

    var body: some View {
        if let model = experience.demoViewModel {
            AppDemoExperienceView(
                root: experience.root,
                model: model,
                navigationCoordinator: experience.root.navigationCoordinator,
                onExit: controller.changeBike
            )
        } else {
            AppRootView(dependencies: experience.root, onExploreDemo: controller.exploreDemo)
        }
    }
}

private struct AppDemoExperienceView: View {
    let root: AppRootDependencies
    let model: BikeDemoViewModel
    @ObservedObject var navigationCoordinator: AppNavigationCoordinator
    let onExit: () -> Void
    @State private var showsControls = false
    @State private var controlsHeight: CGFloat = .zero

    var body: some View {
        AppRootView(
            dependencies: root,
            onExitDemo: onExit,
            destinationBottomInset: controlsHeight + DesignSpace.small * 2,
            dashboardAccessory: { AnyView(demoAccessButton) }
        )
        .overlay(alignment: .bottomLeading) {
            if navigationCoordinator.state.rideNavigationMode != .fullScreen,
               navigationCoordinator.state.root != .dashboard || !navigationCoordinator.state.path.isEmpty {
                demoAccessButton
                    .padding(.horizontal, DesignSpace.large)
                    .padding(.bottom, DesignSpace.small)
            }
        }
        .sheet(isPresented: $showsControls) {
            BikeDemoPanel(state: model.viewState, onSelect: model.select)
        }
    }

    private var demoAccessButton: some View {
        BikeDemoAccessButton { showsControls = true }
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                controlsHeight = height
            }
    }
}
