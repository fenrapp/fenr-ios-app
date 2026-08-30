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
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
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
                .disabled(viewState.isWorking)
                .accessibilityIdentifier("dashboard.bike-lock.action")
            }
            .padding(Constants.cardPadding)
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
                title: "Enter Unlock PIN",
                submit: submitPIN,
                cancel: dismissSheet
            )
        }
    }

    private var header: some View {
        HStack(spacing: DesignSpace.medium) {
            Image(systemName: statusSystemImage)
                .font(.system(size: Constants.iconSize, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: Constants.iconContainerSize, height: Constants.iconContainerSize)
                .background(statusColor.opacity(Constants.iconBackgroundOpacity), in: RoundedRectangle(
                    cornerRadius: Constants.iconCornerRadius,
                    style: .continuous
                ))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(viewState.title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignColor.secondaryText)
                    .tracking(Constants.titleTracking)
                Text(viewState.statusText)
                    .font(.system(size: Constants.statusFontSize, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.minimumTextScale)
            }

            Spacer(minLength: DesignSpace.extraSmall)

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
    }

    private var statusColor: Color {
        guard viewState.isAvailable else { return DesignColor.inactive }
        return viewState.isLocked ? DesignColor.accent : DesignColor.positive
    }

    private var statusSystemImage: String {
        viewState.isLocked ? "lock.fill" : "lock.open.fill"
    }

    private var actionSystemImage: String {
        guard viewState.isConfigured else { return "slider.horizontal.3" }
        return viewState.isLocked ? "lock.open.fill" : "lock.fill"
    }

    private var statusDetail: String {
        guard viewState.isAvailable else {
            return "Requires a compatible VCU connection."
        }
        guard viewState.isConfigured else {
            return "Choose your unlock protection."
        }
        return viewState.isLocked
            ? "Unlock protection is active."
            : "Ready to secure the motorcycle."
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
        static let cardPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 20
        static let iconSize: CGFloat = 28
        static let iconContainerSize: CGFloat = 64
        static let iconCornerRadius: CGFloat = 18
        static let iconBackgroundOpacity = 0.14
        static let statusFontSize: CGFloat = 30
        static let titleTracking: CGFloat = 1.1
        static let minimumTextScale = 0.75
        static let statusDotSize: CGFloat = 10
        static let statusRingOpacity = 0.18
        static let statusRingWidth: CGFloat = 5
        static let statusRingScale = 1.55
    }
}
