import DesignSystem
import SwiftUI

struct DashboardBikeLockCard: View {
    let viewState: BikeLockCardViewState
    let securityOptions: [BikeLockSecurityOptionViewData]
    let performPrimaryAction: () -> Void
    let configure: (String, String) -> Void
    let submitPIN: (String) -> Void
    let dismissSheet: () -> Void

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(alignment: .leading, spacing: DesignSpace.medium) {
                header

                Text(statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(DesignColor.secondaryText)

                if let errorText = viewState.errorText {
                    Text(errorText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DesignColor.critical)
                        .multilineTextAlignment(.center)
                }

                Button(action: performPrimaryAction) {
                    if viewState.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(
                            viewState.actionTitle,
                            systemImage: actionSystemImage
                        )
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .dashboardPagingButton()
                .disabled(!viewState.isActionEnabled)
                .accessibilityIdentifier("dashboard.bike-lock.action")
            }
            .padding(DesignSpace.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: setupBinding) {
            BikeLockSetupView(
                options: securityOptions,
                configure: configure,
                cancel: dismissSheet
            )
        }
        .sheet(isPresented: pinBinding) {
            BikeLockPINEntryView(
                title: rideDashboardLocalized(.rideDashboardBikeLockPinEntryTitle),
                submit: submitPIN,
                cancel: dismissSheet
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            HStack(spacing: DesignSpace.small) {
                Image(systemName: statusSystemImage)
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: Constants.iconContainerSize, height: Constants.iconContainerSize)
                    .background(statusColor.opacity(Constants.iconBackgroundOpacity), in: RoundedRectangle(
                        cornerRadius: DesignRadius.small,
                        style: .continuous
                    ))
                    .accessibilityHidden(true)

                Text(viewState.title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignColor.secondaryText)
                    .tracking(Constants.titleTracking)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(statusColor)
                    .frame(width: Constants.statusDotSize, height: Constants.statusDotSize)
                    .overlay {
                        Circle()
                            .stroke(
                                statusColor.opacity(Constants.statusRingOpacity),
                                lineWidth: Constants.statusRingWidth
                            )
                            .scaleEffect(Constants.statusRingScale)
                    }
                    .accessibilityHidden(true)
            }

            Text(viewState.statusText)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusColor: Color {
        guard viewState.isAvailable else { return DesignColor.inactive }
        return viewState.isLocked ? DesignColor.accent : DesignColor.positive
    }

    private var statusSystemImage: String {
        viewState.isLocked ? "lock.fill" : "lock.open.fill"
    }

    private var actionSystemImage: String {
        if viewState.isLocked { return "lock.open.fill" }
        return viewState.isConfigured ? "lock.fill" : "slider.horizontal.3"
    }

    private var statusDetail: String {
        guard viewState.isAvailable else {
            return rideDashboardLocalized(.rideDashboardBikeLockDetailConnectionRequired)
        }
        guard viewState.isConfigured else {
            return viewState.isLocked
                ? rideDashboardLocalized(.rideDashboardBikeLockDetailNotConfigured)
                : rideDashboardLocalized(.rideDashboardBikeLockDetailChooseProtection)
        }
        return viewState.isLocked
            ? rideDashboardLocalized(.rideDashboardBikeLockDetailProtectionActive)
            : rideDashboardLocalized(.rideDashboardBikeLockDetailReady)
    }

    private var setupBinding: Binding<Bool> {
        .init(
            get: { viewState.sheet == .setup },
            set: { if !$0 { dismissSheet() } }
        )
    }

    private var pinBinding: Binding<Bool> {
        .init(
            get: { viewState.sheet == .enterPIN },
            set: { if !$0 { dismissSheet() } }
        )
    }

    private enum Constants {
        static let iconSize: CGFloat = 26.4
        static let iconContainerSize: CGFloat = 48
        static let iconBackgroundOpacity = 0.14
        static let titleTracking: CGFloat = 1.1
        static let statusDotSize: CGFloat = 10
        static let statusRingOpacity = 0.18
        static let statusRingWidth: CGFloat = 5
        static let statusRingScale = 1.55
    }
}
