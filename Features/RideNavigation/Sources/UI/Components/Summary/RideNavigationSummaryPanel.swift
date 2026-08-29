import DesignSystem
import SwiftUI

struct RideNavigationSummaryPanel: View {
    let state: RideNavigationViewState
    @Binding var routeName: String
    let onSave: () -> Void
    let onExport: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: DesignSpace.large) {
            completionIcon
            summaryHeader
            if state.canSaveCompletedRoute {
                routeNameField
            }
            actions
            if let errorText = state.errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(DesignColor.warning)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSpace.extraLarge)
        .frame(width: Constants.panelWidth)
        .rideNavigationGlassSurface(cornerRadius: Constants.panelRadius)
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
        VStack(spacing: DesignSpace.extraSmall) {
            Text(state.summaryTitle)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(state.summaryDetail)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

    private var actions: some View {
        HStack(spacing: DesignSpace.small) {
            if state.canSaveCompletedRoute {
                Button(action: onSave) {
                    Label("Save Route", systemImage: "square.and.arrow.down.fill")
                }
                .controlSize(.large)
                .rideNavigationPrimaryButton()
            }

            Button(action: onExport) {
                Label("Export GPX", systemImage: "square.and.arrow.up")
            }
            .controlSize(.large)
            .rideNavigationSecondaryButton()

            Button("Done", action: onDone)
                .controlSize(.large)
                .rideNavigationSecondaryButton()
        }
    }

    private enum Constants {
        static let panelWidth: CGFloat = 480
        static let panelRadius: CGFloat = 30
        static let iconSize: CGFloat = 56
        static let iconShadowOpacity = 0.28
        static let iconShadowRadius: CGFloat = 12
        static let fieldHeight: CGFloat = 50
    }
}
