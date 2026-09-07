import DesignSystem
import SwiftUI

struct RideNavigationSummaryPanel: View {
    let state: RideNavigationViewState
    @Binding var routeName: String
    let onSave: () -> Void
    let onRetrySave: () -> Void
    let onDiscardUnsaved: () -> Void
    let onExport: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                panel
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(.zero, proxy.size.height - Constants.minimumVerticalMargin * 2)
                    )
                    .padding(.horizontal, DesignSpace.medium)
                    .padding(.vertical, Constants.minimumVerticalMargin)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var panel: some View {
        VStack(spacing: DesignSpace.large) {
            header

            if state.canSaveCompletedRoute {
                routeNameField
            }

            actions
            errorMessage
        }
        .padding(DesignSpace.large)
        .frame(maxWidth: Constants.panelWidth)
        .rideNavigationGlassSurface(cornerRadius: Constants.panelRadius)
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.top, DesignSpace.medium)
                .padding(.trailing, DesignSpace.medium)
        }
    }

    private var header: some View {
        HStack(spacing: DesignSpace.medium) {
            completionIcon
            summaryHeader
            Spacer(minLength: .zero)
        }
        .padding(.trailing, Constants.closeButtonSize)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .frame(width: Constants.closeButtonSize, height: Constants.closeButtonSize)
                .background(DesignColor.controlSurface, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(state.routePersistence.isSaving)
        .accessibilityLabel(.rideNavigationCloseSummary)
        .accessibilityIdentifier("rideNavigation.summary.close")
    }

    private var completionIcon: some View {
        Image(systemName: state.summaryIsSuccessful ? "checkmark" : "exclamationmark")
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(completionColor.gradient, in: Circle())
            .shadow(
                color: completionColor.opacity(Constants.iconShadowOpacity),
                radius: Constants.iconShadowRadius
            )
            .accessibilityHidden(true)
    }

    private var completionColor: Color {
        state.summaryIsSuccessful ? DesignColor.positive : DesignColor.warning
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(state.summaryTitle)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(state.summaryDetail)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("rideNavigation.summary.detail")
        }
    }

    private var routeNameField: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            Text(.rideNavigationRouteNameLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: DesignSpace.small) {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                TextField(String(localized: .rideNavigationRecordedRidePlaceholder), text: $routeName)
                    .accessibilityIdentifier("rideNavigation.summary.name")
                    .submitLabel(.done)
                    .disabled(state.routePersistence.isSaving)
            }
            .padding(.horizontal, DesignSpace.medium)
            .frame(height: Constants.fieldHeight)
            .background(DesignColor.groupedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let errorText = persistenceErrorText ?? state.errorText {
            Label(errorText, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(DesignColor.warning)
                .multilineTextAlignment(.center)
        }
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignSpace.small) { actionButtons }
            VStack(spacing: DesignSpace.small) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if state.routePersistence.isSaving {
            HStack(spacing: DesignSpace.small) {
                ProgressView()
                Text(.rideNavigationSavingRoute)
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("rideNavigation.routeSaving")
        } else if case .failed = state.routePersistence {
            Button(action: onRetrySave) {
                Label(.rideNavigationRetrySave, systemImage: "arrow.clockwise")
            }
            .controlSize(.large)
            .rideNavigationPrimaryButton()
            .accessibilityIdentifier("rideNavigation.summary.retrySave")

            Button(role: .destructive, action: onDiscardUnsaved) {
                Label(.rideNavigationDiscardRide, systemImage: "trash")
            }
            .controlSize(.large)
            .rideNavigationSecondaryButton()
            .accessibilityIdentifier("rideNavigation.summary.discard")
        } else {
            if state.canSaveCompletedRoute {
                Button(action: onSave) {
                    Label(.rideNavigationSave, systemImage: "square.and.arrow.down.fill")
                }
                .controlSize(.large)
                .rideNavigationPrimaryButton()
                .accessibilityIdentifier("rideNavigation.summary.save")
            }
        }

        if state.canExportCompletedRoute {
            Button(action: onExport) {
                Label(.rideNavigationExportGPX, systemImage: "square.and.arrow.up")
            }
            .controlSize(.large)
            .rideNavigationSecondaryButton()
            .disabled(state.routePersistence.isSaving)
            .accessibilityIdentifier("rideNavigation.summary.export")
        }
    }

    private var persistenceErrorText: String? {
        guard case .failed(let message) = state.routePersistence else { return nil }
        return message
    }

    private enum Constants {
        static let panelWidth: CGFloat = 520
        static let panelRadius: CGFloat = 26
        static let closeButtonSize: CGFloat = 36
        static let iconSize: CGFloat = 52
        static let iconShadowOpacity = 0.28
        static let iconShadowRadius: CGFloat = 12
        static let fieldHeight: CGFloat = 50
        static let minimumVerticalMargin: CGFloat = 16
    }
}
