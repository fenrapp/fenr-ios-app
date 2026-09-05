import DesignSystem
import SwiftUI

struct RideNavigationFinishConfirmationOverlay: View {
    let activity: RideNavigationViewState.Activity
    let arrivalPrompt: RideNavigationArrivalPrompt?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    init(
        activity: RideNavigationViewState.Activity,
        arrivalPrompt: RideNavigationArrivalPrompt? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.activity = activity
        self.arrivalPrompt = arrivalPrompt
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        ZStack {
            Color.black.opacity(Constants.backdropOpacity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            confirmationCard
                .offset(y: -DesignSpace.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: DesignSpace.medium) {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignSpace.small) { actionButtons }
                VStack(alignment: .leading, spacing: DesignSpace.small) { actionButtons }
            }
        }
        .padding(DesignSpace.large)
        .frame(maxWidth: Constants.width)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
        .onTapGesture {}
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(.rideNavigationKeepRiding, action: onCancel)
            .accessibilityIdentifier("rideNavigation.finish.cancel")
            .controlSize(.large)
            .rideNavigationSecondaryButton()
        Button(confirmTitle, action: onConfirm)
            .accessibilityIdentifier("rideNavigation.finish.confirm")
            .controlSize(.large)
            .tint(DesignColor.critical)
            .foregroundStyle(.white)
            .rideNavigationPrimaryButton()
    }

    private var isRecording: Bool {
        activity == .recording || activity == .paused
    }

    private var title: String {
        if let arrivalPrompt { return arrivalPrompt.title }
        return String(localized: isRecording
            ? .rideNavigationFinishRecordingQuestion
            : .rideNavigationEndRouteQuestion)
    }

    private var message: String {
        if let arrivalPrompt { return arrivalPrompt.detail }
        return isRecording
            ? String(localized: .rideNavigationFinishRecordingDetail)
            : String(localized: .rideNavigationEndRouteDetail)
    }

    private var confirmTitle: String {
        if arrivalPrompt != nil { return String(localized: .rideNavigationFinishRoute) }
        return String(localized: isRecording
            ? .rideNavigationFinishRecording
            : .rideNavigationEndRoute)
    }

    private enum Constants {
        static let width: CGFloat = 360
        static let cornerRadius: CGFloat = 24
        static let backdropOpacity = 0.18
    }
}
