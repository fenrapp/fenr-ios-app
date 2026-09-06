import DesignSystem
import SwiftUI

struct WatchOnboardingContentView: View {
    let state: WatchOnboardingViewState
    let select: (WatchDiscoveredBikeViewData) -> Void
    let scan: () -> Void

    var body: some View {
        List {
            Section {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title)
                    .foregroundStyle(.tint)
                Text(.watchOnboardingFindYourBike)
                    .font(.headline)
                Text(verbatim: state.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if state.discoveredBikes.count > 1 {
                Section {
                    ForEach(state.discoveredBikes) { bike in
                        Button {
                            select(bike)
                        } label: {
                            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                                Text(verbatim: bike.vin).font(.caption.monospaced())
                                Text(verbatim: bike.signalText).font(.caption2)
                            }
                        }
                    }
                } header: {
                    Text(.watchOnboardingNearbyBikes)
                }
            }

            if state.discoveredBikes.isEmpty, !state.isConnecting {
                Section {
                    Button(action: scan) {
                        Text(.watchOnboardingScanAgain)
                    }
                }
            }

            if let errorMessage = state.errorMessage {
                Section {
                    Text(verbatim: errorMessage).foregroundStyle(DesignColor.critical)
                    Button(action: scan) {
                        Text(.watchOnboardingTryAgain)
                    }
                }
            }

            if !state.debugEvents.isEmpty {
                Section {
                    ForEach(state.debugEvents) { event in
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            Text(verbatim: event.title)
                                .font(.caption2.weight(.semibold))
                            Text(verbatim: event.detail)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(Constants.debugEventLineLimit)
                        }
                    }
                } header: {
                    Text(.watchOnboardingDebug)
                }
            }
        }
    }

    private enum Constants {
        static let debugEventLineLimit = 4
    }
}
