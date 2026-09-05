import DesignSystem
import SwiftUI

struct DashboardCurrentTripCard: View {
    let state: DashboardCurrentTripViewData
    let freezesDurationUpdates: Bool
    let togglePause: () -> Void
    let reset: () -> Void

    @State private var showsResetConfirmation = false
    @State private var displayedDurationText: String

    init(
        state: DashboardCurrentTripViewData,
        freezesDurationUpdates: Bool,
        togglePause: @escaping () -> Void,
        reset: @escaping () -> Void
    ) {
        self.state = state
        self.freezesDurationUpdates = freezesDurationUpdates
        self.togglePause = togglePause
        self.reset = reset
        _displayedDurationText = State(initialValue: state.durationText)
    }

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                header
                duration
                Divider()
                metric(state.distance, sourceIndicator: state.speedSourceIndicator)
                metric(state.averageSpeed)
                metric(state.maximumSpeed)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .alert(
            rideDashboardLocalized(.rideDashboardCurrentTripResetConfirmationTitle),
            isPresented: $showsResetConfirmation
        ) {
            Button(.rideDashboardCurrentTripResetAction, role: .destructive, action: reset)
            Button(.rideDashboardCommonCancel, role: .cancel) {}
        } message: {
            Text(.rideDashboardCurrentTripResetMessage)
        }
        .onChange(of: freezesDurationUpdates) {
            synchronizeDisplayedDurationIfNeeded()
        }
        .onChange(of: state.durationText) {
            synchronizeDisplayedDurationIfNeeded()
        }
    }

    private var header: some View {
        DashboardTripCardHeader(
            title: rideDashboardLocalized(.rideDashboardCurrentTripTitle),
            subtitle: state.statusText
        ) {
            if state.isActive {
                HStack(spacing: DesignSpace.small) {
                    Button(action: togglePause) {
                        Label(
                            state.isPaused
                                ? rideDashboardLocalized(.rideDashboardCurrentTripActionResume)
                                : rideDashboardLocalized(.rideDashboardCurrentTripActionPause),
                            systemImage: state.isPaused ? "play.fill" : "pause.fill"
                        )
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .frame(width: Constants.controlButtonSize, height: Constants.controlButtonSize)
                        .background(Circle().fill(DesignColor.controlSurface))
                    }
                    .buttonStyle(.plain)
                    .dashboardPagingButton()
                    .accessibilityLabel(
                        state.isPaused
                            ? .rideDashboardCurrentTripAccessibilityResume
                            : .rideDashboardCurrentTripAccessibilityPause
                    )

                    Button {
                        showsResetConfirmation = true
                    } label: {
                        Label(.rideDashboardCurrentTripActionReset, systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                            .font(.body.weight(.semibold))
                            .frame(
                                width: Constants.controlButtonSize,
                                height: Constants.controlButtonSize
                            )
                            .background(Circle().fill(DesignColor.controlSurface))
                    }
                    .buttonStyle(.plain)
                    .dashboardPagingButton()
                    .accessibilityLabel(.rideDashboardCurrentTripAccessibilityReset)
                }
            }
        }
    }

    private var duration: some View {
        Text(displayedDurationText)
            .font(.system(size: Constants.durationFontSize, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(DesignColor.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(Constants.durationMinimumScaleFactor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private func metric(
        _ metric: DashboardCurrentTripViewData.Metric,
        sourceIndicator: DashboardSpeedSourceIndicatorViewData? = nil
    ) -> some View {
        DashboardTripMetricRow(
            label: metric.label,
            valueText: metric.valueText,
            unit: metric.unit,
            systemImage: metric.systemImage
        ) {
            if let sourceIndicator {
                DashboardSpeedSourceChip(state: sourceIndicator, isCompact: true)
            }
        }
    }

    private func synchronizeDisplayedDurationIfNeeded() {
        guard !freezesDurationUpdates,
              displayedDurationText != state.durationText else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            displayedDurationText = state.durationText
        }
    }

    private enum Constants {
        static let sectionSpacing: CGFloat = 10
        static let durationFontSize: CGFloat = 34
        static let durationMinimumScaleFactor: CGFloat = 0.72
        static let controlButtonSize: CGFloat = 36
    }
}
