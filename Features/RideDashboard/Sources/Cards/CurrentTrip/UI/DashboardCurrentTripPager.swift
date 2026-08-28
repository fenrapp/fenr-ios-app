import SwiftUI

struct DashboardCurrentTripPager: View {
    let pages: [CurrentTripDashboardPage]
    @Binding var selection: CurrentTripDashboardPage
    let currentTrip: DashboardCurrentTripViewData
    let statistics: DashboardTripStatisticsViewData
    let reduceMotion: Bool
    let togglePause: () -> Void
    let reset: () -> Void

    @State private var freezesDurationUpdates = false
    @State private var durationReleaseTask: Task<Void, Never>?

    var body: some View {
        DashboardHorizontalCardPager(
            pages: pages,
            selection: $selection,
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
        static let durationReleaseDelay = Duration.milliseconds(1_400)
    }
}
