import DesignSystem
import SwiftUI

struct RideNavigationSummaryPanel: View {
    let state: RideNavigationViewState
    @Binding var routeName: String
    let onSave: () -> Void
    let onExport: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ViewThatFits(in: .vertical) {
                panel

                ScrollView {
                    panel
                }
                .scrollIndicators(.hidden)
                .frame(height: max(.zero, proxy.size.height - Constants.minimumVerticalMargin * 2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, DesignSpace.medium)
            .padding(.vertical, Constants.minimumVerticalMargin)
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
        .accessibilityLabel("Close ride summary")
    }

    private var completionIcon: some View {
        Image(systemName: "checkmark")
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(DesignColor.positive.gradient, in: Circle())
            .shadow(
                color: DesignColor.positive.opacity(Constants.iconShadowOpacity),
                radius: Constants.iconShadowRadius
            )
            .accessibilityHidden(true)
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
        }
    }

    private var routeNameField: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            Text("Route Name")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: DesignSpace.small) {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                TextField("Recorded ride", text: $routeName)
                    .submitLabel(.done)
            }
            .padding(.horizontal, DesignSpace.medium)
            .frame(height: Constants.fieldHeight)
            .background(DesignColor.groupedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let errorText = state.errorText {
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
            if state.canSaveCompletedRoute {
                Button(action: onSave) {
                    Label("Save", systemImage: "square.and.arrow.down.fill")
                }
                .controlSize(.large)
                .rideNavigationPrimaryButton()
            }

            Button(action: onExport) {
                Label("Export GPX", systemImage: "square.and.arrow.up")
            }
            .controlSize(.large)
            .rideNavigationSecondaryButton()
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
