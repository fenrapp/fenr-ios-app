import DesignSystem
import SwiftUI

struct DashboardCurrentTripPager: View {
    @Binding var selection: CurrentTripDashboardPage
    let currentTrip: DashboardCurrentTripViewData
    let statistics: DashboardTripStatisticsViewData
    let reduceMotion: Bool
    let togglePause: () -> Void
    let reset: () -> Void

    @State private var freezesDurationUpdates = false
    @State private var durationReleaseTask: Task<Void, Never>?

    var body: some View {
        DashboardPager(
            pages: CurrentTripDashboardPage.allCases,
            selection: $selection,
            axis: .horizontal,
            reduceMotion: reduceMotion,
            accessibilityLabel: "Current trip pages",
            accessibilityValue: \.accessibilityLabel,
            onInteractionChanged: updateDurationFreeze
        ) { page in
            switch page {
            case .current:
                DashboardCurrentTripCard(
                    state: currentTrip,
                    freezesDurationUpdates: freezesDurationUpdates,
                    togglePause: togglePause,
                    reset: reset
                )
            case .statistics:
                DashboardTripStatisticsCard(state: statistics)
            }
        }
        .overlay(alignment: .bottom) {
            DashboardPageIndicator(
                pages: CurrentTripDashboardPage.allCases,
                selection: selection,
                axis: .horizontal,
                activeColor: DesignColor.informational
            )
            .padding(.bottom, Constants.indicatorBottomPadding)
        }
        .onDisappear {
            durationReleaseTask?.cancel()
            durationReleaseTask = nil
        }
    }

    private func updateDurationFreeze(isInteracting: Bool) {
        if isInteracting {
            freezeDurationUpdates()
        } else {
            scheduleDurationUpdatesRelease()
        }
    }

    private func freezeDurationUpdates() {
        durationReleaseTask?.cancel()
        durationReleaseTask = nil
        freezesDurationUpdates = true
    }

    private func scheduleDurationUpdatesRelease() {
        durationReleaseTask?.cancel()
        durationReleaseTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Constants.durationReleaseDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            freezesDurationUpdates = false
            durationReleaseTask = nil
        }
    }

    private enum Constants {
        static let indicatorBottomPadding: CGFloat = 10
        static let durationReleaseDelay = Duration.milliseconds(1_400)
    }
}
